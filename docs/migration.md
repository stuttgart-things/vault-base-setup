# Migration notes

## v1.2.0 — KV secret keys and the ServiceAccount resource

Two changes move resources to different state addresses. **Both require `terraform state`
surgery before the first apply.** Neither is optional: applying without it destroys live
resources.

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

**Why you cannot skip this:** the old and new instances resolve to the *same Vault path*.
Terraform sees one instance removed and another added, and there is no ordering guarantee
between them. If the destroy runs after the create, **Terraform deletes the secret data it
just wrote.**

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

For every entry in `k8s_auths`:

```bash
terraform state rm 'kubernetes_manifest.service_account["<name>"]'
terraform import 'kubernetes_service_account_v1.vault["<name>"]' '<namespace>/<name>'
```

Concretely, for `{ name = "certmanager-vault", namespace = "cert-manager", ... }`:

```bash
terraform state rm 'kubernetes_manifest.service_account["certmanager-vault"]'
terraform import \
  'kubernetes_service_account_v1.vault["certmanager-vault"]' \
  'cert-manager/certmanager-vault'
```

`terraform state rm` only forgets the resource; it does not touch the cluster. The
ServiceAccount keeps running throughout.

Then verify:

```bash
terraform plan
# expect: No changes, or at most an in-place update
```

An in-place diff on `automount_service_account_token` is harmless. A **destroy** of the
ServiceAccount is not — that means the import did not land.

---

### Not affected

`vso.tf` still uses `kubernetes_manifest` for `VaultConnection` and `VaultAuth`. Those are
gated behind `vso_enabled`, so with the default `vso_enabled = false` there are no
instances and plan-time cluster access is not required. With `vso_enabled = true` the
plan-time constraint still applies.
