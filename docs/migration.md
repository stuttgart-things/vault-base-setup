# Migration notes

## Unreleased — the token reviewer moves off the login ServiceAccount

A Kubernetes auth mount needs two identities, and this module used one for both:

| | Needs | Previously | Now |
|---|---|---|---|
| **Reviewer** — whose JWT Vault presents to TokenReview | `system:auth-delegator` | the login SA | `vault-auth-reviewer` in `kube-system`, shared by every mount |
| **Login SA** — the workload authenticating | nothing | held `system:auth-delegator` | holds nothing |

`system:auth-delegator` is the right to review **any** token in the cluster. Handing
that to cert-manager so it can authenticate itself is not a trade anybody would make
deliberately; it was a side effect of one ServiceAccount doing two jobs. The VM
pipeline's `CreateVaultKubernetesAuth` has always used a separate reviewer — this
brings the module in line.

Configurable via `k8s_auth_reviewer_name` / `k8s_auth_reviewer_namespace`, or per entry
with `reviewer_name` / `reviewer_namespace` on `k8s_auths`.

### What the first plan does

**No `terraform state` surgery.** Nothing moves address; resources are added and
removed. Expect, per `k8s_auths` entry:

```
# kubernetes_cluster_role_binding.vault["<name>"]           destroyed
# kubernetes_secret.vault["<name>"]                         destroyed
# kubernetes_service_account_v1.reviewer[...]               created
# kubernetes_secret_v1.reviewer[...]                        created
# kubernetes_cluster_role_binding.reviewer[...]             created
# vault_kubernetes_auth_backend_config.kubernetes["<name>"] updated in-place
```

The reviewer resources are keyed `<namespace>/<name>` and created **once** per distinct
reviewer, not once per mount — several mounts sharing one reviewer is the normal case.

### The window that matters

`vault_kubernetes_auth_backend_config` is updated **in place** with the new
`token_reviewer_jwt`. Between destroying the old ClusterRoleBinding and that update
landing, Vault holds a JWT whose ServiceAccount no longer has `system:auth-delegator`,
and **logins fail with `permission denied`**. Terraform orders this correctly within one
apply, so the window is seconds — but it is not zero, and an apply that fails part-way
leaves it open.

If that matters, verify a login before walking away:

```bash
kubectl -n <namespace> create token <login-sa> --duration=10m > /tmp/t
vault write auth/<cluster>-<name>/login role=<name> jwt=@/tmp/t
```

A `ClusterIssuer` will **not** tell you: cert-manager reports `Ready` off a successful
login at setup and never re-checks. Only an issued `Certificate` proves it.

### The login SA's token Secret is gone

`kubernetes_secret.vault` existed solely to feed `token_reviewer_jwt`. Nothing reads it
now, and a long-lived ServiceAccount token sitting in a namespace is exactly the kind of
standing credential this module should not leave behind. It is destroyed.

If something outside this module reads that Secret, it breaks. Nothing in this repo does.

### Not affected

The login ServiceAccount itself is still created for every entry, including when
`bound_service_account_names` admits somebody else's. Making that conditional is a
separate behaviour change and is not part of this one.

---

## v1.2.0 — KV secret keys and the ServiceAccount resource

Two changes move resources to different state addresses. **Both need `terraform state`
surgery before the first apply.** Applying without it makes Terraform destroy and recreate
live resources instead of recognising them — recoverable in both cases, but not something
to walk into unprepared. The exact consequences are spelled out per change below.

Run all commands with the same backend configuration you normally use, and take a state
backup first:

```bash
terraform state pull > terraform.tfstate.backup.json
```

If the module is called as `module.vault-base-setup`, prefix every address accordingly —
`module.vault-base-setup.vault_generic_secret.kvv2["apps"]`. Adjust the prefix to your
module name; `terraform state list` shows the exact addresses.

---

### 1. `vault_generic_secret.kvv2` is now keyed by `<path>/<name>`

Previously both the mount and the secret were keyed on `path`, which made two secrets in
one mount a hard `Duplicate object key` error and forced one mount per secret. Secrets are
now keyed on `<path>/<name>`.

`vault_mount.kvv2` keys are **unchanged** (still the path). Only the secret addresses move.

**Why you should not skip this.** Old and new instances resolve to the *same Vault path*, so
without the move the plan reads:

```
module...vault_generic_secret.kvv2["ssh"] will be destroyed
  (because key ["ssh"] is not in for_each map)
module...vault_generic_secret.kvv2["ssh/sthings"] will be created

Plan: 2 to add, 0 to change, 2 to destroy.
```

Terraform does not order a destroy of one instance against the create of another. Whether
the secret survives depends on which finishes last.

This was tested against a throwaway Vault. In that run the creates completed after the
destroys and **the data survived** — the path ended at KV v2 version 2, with version 1
soft-deleted:

```
v1: destroyed=False  deletion_time='2026-07-22T14:02:57Z'
v2: destroyed=False  deletion_time=''
```

So this is a race, not a guaranteed wipe, and the losing outcome is recoverable: Vault KV v2
performs a **soft** delete (`destroyed=false`), so a secret that ends up deleted can be
brought back with

```bash
vault kv undelete -mount=<path> -versions=<n> <name>
```

None of that makes skipping the move a good idea — it churns a new version onto every
secret and leaves the outcome to chance. Move them instead:

For every entry in `secret_engines`:

```bash
terraform state mv \
  'vault_generic_secret.kvv2["<path>"]' \
  'vault_generic_secret.kvv2["<path>/<name>"]'
```

Concretely, for `{ name = "creds", path = "apps", ... }`:

```bash
terraform state mv \
  'vault_generic_secret.kvv2["apps"]' \
  'vault_generic_secret.kvv2["apps/creds"]'
```

Then confirm the plan is clean before applying:

```bash
terraform plan
# expect: No changes. Your infrastructure matches the configuration.
```

**If `terraform plan` shows any `vault_generic_secret` being destroyed, stop.** An address
was missed. Re-check `terraform state list` against your `secret_engines` entries.

#### Optional: collapse redundant mounts

The one-mount-per-secret workaround is no longer necessary, so entries can now share a
path. Doing so is a *separate* change — it destroys the now-unused mounts **and every
secret in them**. Move the secrets to the surviving mount first, or write them fresh.
Nothing forces you to consolidate; existing layouts keep working untouched.

When several entries share a path, the mount `description` comes from the first entry
listed for that path.

---

### 2. `kubernetes_manifest.service_account` → `kubernetes_service_account_v1.vault`

The ServiceAccount created for `k8s_auths` no longer uses `kubernetes_manifest`, which
performs a server-side lookup during **plan** and therefore breaks any `terraform plan`
without cluster access — plan-only CI pipelines in particular.

`moved` blocks cannot express this: they do not support changing resource type. The state
entry has to be dropped and re-imported.

**Why you cannot skip this:** otherwise Terraform destroys and recreates the ServiceAccount.
Deleting it invalidates its long-lived token Secret, which is the `token_reviewer_jwt` in
`vault_kubernetes_auth_backend_config` — Vault Kubernetes auth stops working until a
subsequent apply repairs it.

> **Do not use the `terraform import` CLI command here — it fails against this module.**
> `auth.tf` derives `for_each` keys from resource attributes:
>
> ```hcl
> resource "vault_approle_auth_backend_role_secret_id" "approle_secret" {
>   for_each = {
>     for role in vault_approle_auth_backend_role.approle :
>     role.role_name => role
>   }
> ```
>
> The import code path rejects that as *"keys derived from resource attributes that cannot
> be determined until apply"* — even when `approle_roles` is empty and the map is provably
> empty. `terraform plan` handles it fine, so use a config `import` block instead, which
> goes through a normal plan.

For every entry in `k8s_auths`, first drop the old address:

```bash
terraform state rm 'kubernetes_manifest.service_account["<name>"]'
```

`terraform state rm` only forgets the resource; it does not touch the cluster. The
ServiceAccount keeps running throughout.

Then add a temporary `import` block to your configuration:

```hcl
import {
  to = module.vault-base-setup.kubernetes_service_account_v1.vault["<name>"]
  id = "<namespace>/<name>"
}
```

Concretely, for `{ name = "certmanager-vault", namespace = "cert-manager", ... }`:

```hcl
import {
  to = module.vault-base-setup.kubernetes_service_account_v1.vault["certmanager-vault"]
  id = "cert-manager/certmanager-vault"
}
```

Plan and apply — expect `1 to import, 0 to destroy` — then **delete the `import` block
again**; it has served its purpose.

Then verify:

```bash
terraform plan
# expect: No changes, or at most an in-place update
```

An in-place diff on `automount_service_account_token` is harmless. A **destroy** of the
ServiceAccount is not — that means the import did not land.

---

### Also watch for: a `vault-pki-ca` Secret collision

Callers coming from **v1.0.0** may hit this. Since v1.1.0 the ClusterIssuer references its CA
via `caBundleSecretRef`, and the module creates that Secret itself as
`"${certmanager_vault_issuer_name}-ca"` — by default `vault-pki-ca`. If your root module
already declares a Secret of that name (a common pattern before v1.1.0), two Terraform
resources now fight over one Kubernetes object and the apply dies partway with
`AlreadyExists`.

Both write the same content, so hand ownership to the module and delete your own
declaration:

```bash
terraform state mv \
  'kubernetes_secret_v1.<your_name>' \
  'module.vault-base-setup.kubernetes_secret_v1.vault_ca_bundle[0]'
```

### Not affected

`vso.tf` still uses `kubernetes_manifest` for `VaultConnection` and `VaultAuth`. Those are
gated behind `vso_enabled`, so with the default `vso_enabled = false` there are no
instances and plan-time cluster access is not required. With `vso_enabled = true` the
plan-time constraint still applies.

---

## Verified

The KV part of this migration was rehearsed end to end against a throwaway Vault
(`hashicorp/vault:1.20` dev server), using a fixture shaped like a real consumer — two
mounts, one secret each, keyed the old way.

- Applying v1.2.0 **without** the move plans `2 to add, 0 to change, 2 to destroy` on the
  same Vault paths. Applied anyway, the data survived in that run (see the race note above).
- Applying **with** the two `terraform state mv` commands yields exactly
  `No changes. Your infrastructure matches the configuration.`
- Adding further entries that share a path then works: two mounts carrying four secrets,
  all readable, which the previous keying made impossible.

The ServiceAccount part was executed for real on a live cluster
(`platform-sthings/vault-cert-issuer`, one `k8s_auths` entry):

- The `terraform import` CLI command **failed** — hence the `import` block above.
- With `state rm` + `import` block the plan was `1 to import, 0 to add, 1 to change,
  0 to destroy`, and afterwards `No changes.`
- The ServiceAccount kept its original `creationTimestamp` — it was never recreated — and a
  test certificate issued through the Vault-Kubernetes-auth ClusterIssuer still succeeded,
  confirming the imported ServiceAccount still works as the login identity.
- The one in-place change was the ClusterIssuer switching from inline `caBundle` to
  `caBundleSecretRef`, as expected.
