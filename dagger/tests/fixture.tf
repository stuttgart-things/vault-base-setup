terraform {
  required_version = ">= 1.10.0"
}

variable "vault_addr" {
  type = string
}

variable "skip_tls_verify" {
  type    = bool
  default = false
}

# Bogus kubeconfig needed to satisfy the module's kubeconfig validation
# (k8s.tf). No K8s-backed resources are created in this test, so the
# providers configured from it are never actually called.
variable "dummy_kubeconfig" {
  type    = string
  default = <<-EOT
    apiVersion: v1
    kind: Config
    clusters:
      - name: dagger
        cluster:
          server: https://127.0.0.1:6443
          certificate-authority-data: ""
    users:
      - name: dagger
        user:
          client-certificate-data: ""
          client-key-data: ""
    contexts:
      - name: dagger
        context:
          cluster: dagger
          user: dagger
    current-context: dagger
  EOT
}

module "vault_base_setup" {
  source = "../../"

  vault_addr         = var.vault_addr
  skip_tls_verify    = var.skip_tls_verify
  kubeconfig_content = var.dummy_kubeconfig
  cluster_name       = "dagger-test"

  # Keep Kubernetes / Helm driven features off - we test Vault-API features only.
  vault_enabled                    = false
  csi_enabled                      = false
  vso_enabled                      = false
  certmanager_enabled              = false
  certmanager_bootstrap_enabled    = false
  certmanager_vault_issuer_enabled = false

  enableApproleAuth        = true
  enableUserPass           = true
  createDefaultAdminPolicy = true

  approle_roles = [
    { name = "app", token_policies = ["read-app-kv"] },
  ]

  user_list = [
    {
      path      = "auth/userpass/users/tester"
      data_json = jsonencode({ password = "dagger-test", policies = "read-app-kv" })
    },
  ]

  secret_engines = [
    {
      path        = "apps"
      name        = "app"
      description = "dagger test secrets"
      data_json = jsonencode({
        username = "foo"
        password = "bar" # pragma: allowlist secret
      })
    },
  ]

  kv_policies = [
    {
      name         = "read-app-kv"
      capabilities = <<-EOT
        path "apps/data/app" {
          capabilities = ["read"]
        }
      EOT
    },
  ]

  pki_enabled      = true
  pki_path         = "pki"
  pki_common_name  = "dagger.example.com"
  pki_organization = "stuttgart-things"
  pki_country      = "DE"

  pki_roles = [
    {
      name             = "dagger-role"
      allowed_domains  = ["dagger.example.com"]
      allow_subdomains = true
      max_ttl          = "72h"
    },
  ]
}

output "role_ids" {
  value = module.vault_base_setup.role_id
}

output "pki_path" {
  value = module.vault_base_setup.pki_path
}

output "pki_roles" {
  value = module.vault_base_setup.pki_roles
}
