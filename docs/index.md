# vault-base-setup

Terraform module for base-setup configuration of HashiCorp Vault.

## Features

| Feature | Variable | Description |
|---------|----------|-------------|
| KV Secrets Engines | `secret_engines` | Mount KV v2 secrets engines and write initial secrets |
| KV Policies | `kv_policies` | Create ACL policies for KV access |
| Kubernetes Auth | `k8s_auths` | Configure Kubernetes auth backends for service account authentication |
| AppRole Auth | `enableApproleAuth`, `approle_roles` | Enable AppRole auth with configurable roles |
| UserPass Auth | `enableUserPass`, `user_list` | Enable username/password authentication |
| CSI Provider | `csi_enabled` | Deploy Secrets Store CSI Driver integration |
| VSO | `vso_enabled` | Deploy Vault Secrets Operator |
| Vault Server | `vault_enabled` | Deploy Vault server via Bitnami Helm chart with optional ingress/TLS or Gateway API |
| Vault Auto-Unseal | `vault_autounseal_enabled` | Automatically initialize and unseal Vault using vault-autounseal |
| **PKI CA** | `pki_enabled` | Mount PKI secrets engine with root CA for cert-manager integration |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.10.5 |
| vault provider | >= 3.21.0 |
| kubernetes provider | >= 2.24.0 |
| helm provider | >= 2.12.1 |

## Quick Start

```hcl
module "vault-base-setup" {
  source          = "github.com/stuttgart-things/vault-base-setup"
  vault_addr      = "https://vault.example.com"
  skip_tls_verify = true
  kubeconfig_path = "/path/to/kubeconfig"
  cluster_name    = "my-cluster"
  csi_enabled     = false
  vso_enabled     = false
}
```

## Authentication

The module authenticates to Vault using the `VAULT_TOKEN` environment variable:

```bash
export VAULT_ADDR=https://vault.example.com
export VAULT_TOKEN=hvs.<token>
terraform init
terraform apply
```
