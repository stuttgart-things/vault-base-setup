# Vault Deployment

Deploy a Vault server using the Bitnami Helm chart with optional auto-unseal, ingress/TLS, and Gateway API support.

## Variables

### Vault Server

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vault_enabled` | bool | `false` | Enable Vault server deployment |
| `namespace_vault` | string | `"vault"` | Namespace for Vault server deployment |
| `vault_chart_repository` | string | `"oci://registry-1.docker.io/bitnamicharts/vault"` | OCI Helm chart repository |
| `vault_chart_version` | string | `"1.9.0"` | Helm chart version |
| `vault_image_registry` | string | `"ghcr.io"` | Vault server image registry |
| `vault_image_repository` | string | `"stuttgart-things/vault"` | Vault server image repository |
| `vault_image_tag` | string | `"1.20.2-debian-12-r2"` | Vault server image tag |
| `vault_injector_enabled` | bool | `false` | Enable Vault injector |
| `vault_storage_class` | string | `""` | Storage class for persistent volumes (empty = cluster default) |
| `vault_volume_permissions` | bool | `true` | Enable init container to fix volume permissions |
| `vault_wait` | bool | `false` | Whether to wait for Vault pods to be ready (set to false when using auto-unseal) |
| `vault_atomic` | bool | `false` | Whether to rollback Vault Helm release on failure |
| `vault_injector_image_registry` | string | `"ghcr.io"` | Injector image registry |
| `vault_injector_image_repository` | string | `"stuttgart-things/vault-k8s"` | Injector image repository |
| `vault_injector_image_tag` | string | `"1.7.0-debian-12-r4"` | Injector image tag |
| `vault_os_shell_image_registry` | string | `"ghcr.io"` | OS shell image registry |
| `vault_os_shell_image_repository` | string | `"stuttgart-things/os-shell"` | OS shell image repository |
| `vault_os_shell_image_tag` | string | `"12-debian-12-r50"` | OS shell image tag |

### Auto-Unseal

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vault_autounseal_enabled` | bool | `false` | Enable vault-autounseal for automatic init and unseal |
| `vault_autounseal_chart_version` | string | `"0.5.3"` | vault-autounseal Helm chart version |
| `vault_autounseal_secret_shares` | number | `3` | Number of key shares for Vault unseal |
| `vault_autounseal_secret_threshold` | number | `2` | Number of key shares required to unseal |

### Ingress

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vault_ingress_enabled` | bool | `false` | Enable ingress for Vault |
| `vault_ingress_class` | string | `"nginx"` | Ingress class name |
| `vault_ingress_hostname` | string | `""` | Hostname for Vault ingress |
| `vault_ingress_issuer_name` | string | `""` | cert-manager issuer name |
| `vault_ingress_issuer_kind` | string | `"ClusterIssuer"` | cert-manager issuer kind (`ClusterIssuer` or `Issuer`) |

### Gateway API

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vault_gateway_enabled` | bool | `false` | Enable Gateway API HTTPRoute for Vault |
| `vault_gateway_hostname` | string | `""` | Hostname for the HTTPRoute |
| `vault_gateway_name` | string | `""` | Name of the Gateway resource |
| `vault_gateway_namespace` | string | `"default"` | Namespace of the Gateway resource |
| `vault_gateway_section` | string | `"https"` | Gateway listener section name |

## Basic Deployment

When `vault_autounseal_enabled` is `true`, the [vault-autounseal](https://github.com/pytoshka/vault-autounseal) chart is deployed alongside Vault. It watches for the Vault pod (`app.kubernetes.io/component=server`) and automatically initializes and unseals it. Unseal keys and the root token are stored as Kubernetes secrets in the Vault namespace:

- `vault-keys` — contains the unseal key shares
- `vault-root-token` — contains the root token

Retrieve the root token:

```bash
kubectl get secret vault-root-token -n vault -o jsonpath='{.data.root_token}' | base64 -d
```

```hcl
module "vault-base-setup" {
  source                   = "github.com/stuttgart-things/vault-base-setup"
  vault_addr               = "https://vault.example.com"
  cluster_name             = "my-cluster"
  context                  = "default"
  skip_tls_verify          = true
  kubeconfig_path          = "/home/sthings/.kube/my-cluster"
  vault_enabled            = true
  vault_injector_enabled   = false
  namespace_vault          = "vault"
  vault_storage_class      = "openebs-hostpath"
  vault_autounseal_enabled = true
  csi_enabled              = false
  vso_enabled              = false
}
```

## Ingress/TLS Deployment

When `vault_ingress_enabled` is `true`, both `vault_ingress_hostname` and `vault_ingress_issuer_name` are required. The module automatically sets the correct cert-manager annotation based on `vault_ingress_issuer_kind`.

```hcl
module "vault-base-setup" {
  source                    = "github.com/stuttgart-things/vault-base-setup"
  vault_addr                = "https://vault.demo-infra.example.com"
  cluster_name              = "my-cluster"
  context                   = "default"
  skip_tls_verify           = true
  kubeconfig_path           = "/home/sthings/.kube/my-cluster"
  vault_enabled             = true
  vault_injector_enabled    = false
  namespace_vault           = "vault"
  vault_storage_class       = "openebs-zfs"
  vault_autounseal_enabled  = true
  vault_ingress_enabled     = true
  vault_ingress_class       = "nginx"
  vault_ingress_hostname    = "vault.demo-infra.example.com"
  vault_ingress_issuer_name = "cluster-issuer-approle"
  vault_ingress_issuer_kind = "ClusterIssuer"
  csi_enabled               = false
  vso_enabled               = false
}
```

## Gateway API Deployment

For clusters using Gateway API (e.g. Cilium Gateway), the module creates an HTTPRoute that attaches to an existing Gateway resource.

```hcl
module "vault-base-setup" {
  source                   = "github.com/stuttgart-things/vault-base-setup"
  vault_addr               = "https://vault.whatever.sthings-vsphere.labul.sva.de"
  cluster_name             = "my-cluster"
  context                  = "default"
  skip_tls_verify          = true
  kubeconfig_path          = "/home/sthings/.kube/my-cluster"
  vault_enabled            = true
  vault_injector_enabled   = false
  namespace_vault          = "vault"
  vault_storage_class      = "openebs-hostpath"
  vault_autounseal_enabled = true
  vault_gateway_enabled    = true
  vault_gateway_hostname   = "vault.whatever.sthings-vsphere.labul.sva.de"
  vault_gateway_name       = "whatever-gateway"
  vault_gateway_namespace  = "default"
  vault_gateway_section    = "https"
  csi_enabled              = false
  vso_enabled              = false
}
```

## Custom Image Registries

All images can be pointed to a custom registry for air-gapped or private environments:

```hcl
module "vault-base-setup" {
  source                          = "github.com/stuttgart-things/vault-base-setup"
  vault_addr                      = "https://vault.example.com"
  cluster_name                    = "prod-cluster"
  context                         = "prod-cluster"
  kubeconfig_path                 = "/path/to/kubeconfig"
  vault_enabled                   = true
  vault_chart_repository          = "oci://registry.example.com/charts/vault"
  vault_chart_version             = "1.9.0"
  vault_image_registry            = "registry.example.com"
  vault_image_repository          = "vault"
  vault_image_tag                 = "1.20.2-debian-12-r2"
  vault_injector_image_registry   = "registry.example.com"
  vault_injector_image_repository = "vault-k8s"
  vault_injector_image_tag        = "1.7.0-debian-12-r4"
  vault_os_shell_image_registry   = "registry.example.com"
  vault_os_shell_image_repository = "os-shell"
  vault_os_shell_image_tag        = "12-debian-12-r50"
  csi_enabled                     = false
  vso_enabled                     = false
}
```
