# PKI CA Bootstrap Workflow

When Vault is the PKI CA but is itself exposed via ingress requiring TLS, there is a chicken-and-egg problem: you need a certificate to secure Vault's ingress, but Vault isn't running yet to issue certificates. This module solves it with a bootstrap workflow.

## Architecture

```text
Phase 1 (First Apply):

  cert-manager Helm
        |
        v
  self-signed ClusterIssuer
        |
        v
  CA Certificate (isCA=true, ECDSA P-256)
        |
        v
  bootstrap-ca-issuer (CA ClusterIssuer)
        |
        v
  Vault deployed with TLS ingress (signed by bootstrap CA)
        |
        v
  vault-autounseal initializes + unseals Vault

Phase 2 (Second Apply):

  Vault PKI engine configured (pki.tf)
        |
        v
  Vault token (scoped to pki-issue policy)
        |
        v
  K8s secret (token stored in cert-manager namespace)
        |
        v
  Vault ClusterIssuer (with caBundle from bootstrap CA)
```

## Two-Phase Apply

This is required because the Vault provider needs a running, unsealed Vault to configure PKI resources.

**First apply** deploys:

- cert-manager + CRDs
- Self-signed ClusterIssuer + bootstrap CA + CA ClusterIssuer
- Vault with TLS ingress (using bootstrap CA issuer)
- vault-autounseal (initializes and unseals Vault)

**Second apply** configures:

- Vault PKI secrets engine, root CA, roles, and policy
- Vault token scoped to `pki-issue` policy
- Kubernetes secret with the token
- Vault-backed ClusterIssuer

## Variables

### cert-manager

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `certmanager_enabled` | bool | `false` | Deploy cert-manager via Helm |
| `certmanager_namespace` | string | `"cert-manager"` | Namespace for cert-manager |
| `certmanager_chart_version` | string | `"v1.17.1"` | cert-manager Helm chart version |

### Bootstrap CA

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `certmanager_bootstrap_enabled` | bool | `false` | Create self-signed CA bootstrap chain |
| `certmanager_selfsigned_issuer_name` | string | `"selfsigned-issuer"` | Self-signed ClusterIssuer name |
| `certmanager_bootstrap_ca_name` | string | `"bootstrap-ca"` | Bootstrap CA Certificate name |
| `certmanager_bootstrap_ca_common_name` | string | `"Bootstrap CA"` | CA certificate common name |
| `certmanager_bootstrap_ca_secret_name` | string | `"bootstrap-ca-secret"` | Secret for CA key pair |
| `certmanager_bootstrap_ca_duration` | string | `"87600h"` | CA certificate duration (10 years) |
| `certmanager_bootstrap_ca_issuer_name` | string | `"bootstrap-ca-issuer"` | CA ClusterIssuer name |

### Vault ClusterIssuer

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `certmanager_vault_issuer_enabled` | bool | `false` | Create Vault-backed ClusterIssuer |
| `certmanager_vault_issuer_name` | string | `"vault-pki"` | Vault ClusterIssuer name |
| `certmanager_vault_issuer_namespace` | string | `"cert-manager"` | Namespace for Vault token secret |
| `certmanager_vault_issuer_pki_role` | string | `""` | PKI role for certificate issuance |
| `certmanager_vault_token_ttl` | string | `"720h"` | Vault token TTL |
| `certmanager_vault_token_secret_name` | string | `"vault-pki-token"` | K8s secret name for Vault token |

## Outputs

| Output | Description |
|--------|-------------|
| `certmanager_bootstrap_ca_issuer` | Bootstrap CA ClusterIssuer name |
| `certmanager_vault_issuer` | Vault-backed ClusterIssuer name |

## Full Example

```hcl
module "vault-base-setup" {
  source          = "github.com/stuttgart-things/vault-base-setup"
  vault_addr      = "https://vault.demo-infra.example.com"
  cluster_name    = "my-cluster"
  context         = "default"
  skip_tls_verify = true
  kubeconfig_path = "/home/sthings/.kube/my-cluster"

  # Deploy Vault with auto-unseal
  vault_enabled            = true
  vault_injector_enabled   = false
  namespace_vault          = "vault"
  vault_storage_class      = "openebs-zfs"
  vault_autounseal_enabled = true

  # Deploy cert-manager + bootstrap CA
  certmanager_enabled           = true
  certmanager_bootstrap_enabled = true

  # Ingress with TLS (issuer auto-wired from bootstrap CA)
  vault_ingress_enabled  = true
  vault_ingress_class    = "nginx"
  vault_ingress_hostname = "vault.demo-infra.example.com"

  # PKI CA (configured on second apply)
  pki_enabled      = true
  pki_common_name  = "example.com"
  pki_organization = "My Org"
  pki_roles = [
    {
      name             = "example-dot-com"
      allowed_domains  = ["example.com"]
      allow_subdomains = true
      max_ttl          = "720h"
    }
  ]

  # Vault ClusterIssuer (configured on second apply)
  certmanager_vault_issuer_enabled  = true
  certmanager_vault_issuer_pki_role = "example-dot-com"

  csi_enabled = false
  vso_enabled = false
}
```

### Apply

```bash
export VAULT_TOKEN=hvs.<token>

# Phase 1: deploy cert-manager + bootstrap CA + Vault
terraform init
terraform apply \
  -target=helm_release.cert_manager \
  -target=kubectl_manifest.bootstrap_ca_clusterissuer \
  -target=helm_release.vault \
  -target=helm_release.vault_autounseal

# Wait for Vault to be initialized and unsealed
kubectl get secret vault-root-token -n vault -o jsonpath='{.data.root_token}' | base64 -d

# Phase 2: configure PKI + create Vault ClusterIssuer
export VAULT_TOKEN=hvs.<root-token-from-above>
terraform apply
```

### Verify

```bash
# Both issuers should be Ready
kubectl get clusterissuer
# NAME                  READY   AGE
# selfsigned-issuer     True    5m
# bootstrap-ca-issuer   True    5m
# vault-pki             True    1m

# Test certificate issuance via Vault
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-vault-cert
  namespace: default
spec:
  secretName: test-vault-cert
  issuerRef:
    name: vault-pki
    kind: ClusterIssuer
  commonName: test.example.com
  dnsNames:
    - test.example.com
EOF

kubectl get certificate test-vault-cert
```

## How It Works

1. **cert-manager** is deployed via Helm with CRDs enabled
2. A **self-signed ClusterIssuer** is created as the trust root
3. A **CA Certificate** is issued by the self-signed issuer (ECDSA P-256, `isCA=true`)
4. A **CA ClusterIssuer** uses the CA certificate's secret to sign certificates
5. **Vault's ingress** is annotated with the bootstrap CA issuer (auto-wired when `vault_ingress_issuer_name` is empty)
6. After Vault is running, **PKI is configured** with a root CA and issuance roles
7. A scoped **Vault token** is created and stored as a Kubernetes secret
8. A **Vault-backed ClusterIssuer** is created with the token and the bootstrap CA's `caBundle`

The bootstrap CA is only used for Vault's own ingress TLS. All other certificates should use the Vault ClusterIssuer.
