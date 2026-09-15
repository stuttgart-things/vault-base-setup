terraform {
  required_version = ">= 1.10.5"
}

module "vault-secrets-setup" {
  source                   = "../"
  kubeconfig_path          = "/home/sthings/.kube/kind-helm-dev"
  context                  = "kind-helm-dev"
  vault_addr               = "https://vault.172.18.0.2.nip.io"
  cluster_name             = "kind-helm-dev"
  createDefaultAdminPolicy = true
  csi_enabled              = false
  vso_enabled              = false
  enableApproleAuth        = true
  skip_tls_verify          = true

  approle_roles = [
    {
      name           = "s3"
      token_policies = ["read-write-all-s3-kvv2"]
    },
    {
      # PER-ROLE SETTINGS: short-lived tokens, and no secret_id minted by this
      # module — the shape of a role whose credentials are handed out elsewhere.
      name             = "s3-short-lived"
      token_policies   = ["read-write-all-s3-kvv2"]
      token_ttl        = 1200
      token_max_ttl    = 1800
      create_secret_id = false
    },
  ]

  secret_engines = [
    {
      path        = "apps"
      name        = "s3"
      description = "minio app secrets"
      data_json   = <<EOT
      {
        "accessKey": "this",
        "secretKey": "andThat" # pragma: allowlist secret
      }
      EOT
    }
  ]

  kv_policies = [
    {
      name         = "read-write-all-s3-kvv2"
      capabilities = <<EOF
path "apps/data/s3" {
    capabilities = ["create", "read", "update", "patch", "list"]
}
EOF
    }
  ]

}

output "role_ids" {
  description = "Role IDs from the vault approle module"
  value       = module.vault-secrets-setup.role_id
}

output "secret_ids" {
  description = "Secret IDs from the vault approle module"
  value       = module.vault-secrets-setup.secret_id
  sensitive   = true
}
