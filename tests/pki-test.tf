terraform {
  required_version = ">= 1.10.5"
}

module "vault-pki-test" {
  source          = "../"
  vault_addr      = "https://vault.demo-infra.sthings-vsphere.labul.sva.de"
  skip_tls_verify = true
  kubeconfig_path = "/home/sthings/.kube/demo-infra"
  cluster_name    = "demo-infra"

  # Disable features we don't need for this test
  csi_enabled              = false
  vso_enabled              = false
  enableApproleAuth        = false
  createDefaultAdminPolicy = false
  enableUserPass           = false
  vault_enabled            = false

  # PKI CA configuration
  pki_enabled      = true
  pki_path         = "pki"
  pki_common_name  = "sthings-vsphere.labul.sva.de"
  pki_organization = "sva"
  pki_country      = "DE"
  pki_key_type     = "rsa"
  pki_key_bits     = 2048
  pki_root_ttl     = "87600h"

  pki_roles = [
    {
      name             = "sthings-vsphere"
      allowed_domains  = ["sthings-vsphere.labul.sva.de"]
      allow_subdomains = true
      max_ttl          = "720h"
    }
  ]
}

output "pki_ca_cert" {
  description = "PKI root CA certificate"
  value       = module.vault-pki-test.pki_ca_cert
  sensitive   = true
}

output "pki_path" {
  description = "PKI secrets engine mount path"
  value       = module.vault-pki-test.pki_path
}

output "pki_roles" {
  description = "Created PKI role names"
  value       = module.vault-pki-test.pki_roles
}
