output "role_id" {
  description = "Role IDs as a list, ordered by role name. Prefer role_ids, which is keyed by name."
  value = [
    for role in vault_approle_auth_backend_role.approle : role.role_id
  ]
}

output "role_ids" {
  description = "Role IDs keyed by role name"
  value = {
    for role_name, role in vault_approle_auth_backend_role.approle :
    role_name => role.role_id
  }
}

output "secret_id" {
  description = "Secret IDs keyed by role name. Only roles with create_secret_id = true (the default) appear here."
  value = {
    for role_name, secret in vault_approle_auth_backend_role_secret_id.approle_secret :
    role_name => secret.secret_id
  }
  sensitive = true
}

output "pki_ca_cert" {
  description = "PKI root CA certificate"
  value       = var.pki_enabled ? vault_pki_secret_backend_root_cert.root[0].certificate : null
}

output "pki_path" {
  description = "PKI secrets engine mount path"
  value       = var.pki_enabled ? vault_mount.pki[0].path : null
}

output "pki_roles" {
  description = "PKI role names"
  value = [
    for role in vault_pki_secret_backend_role.roles : role.name
  ]
}

output "certmanager_bootstrap_ca_issuer" {
  description = "Bootstrap CA ClusterIssuer name"
  value       = var.certmanager_bootstrap_enabled ? var.certmanager_bootstrap_ca_issuer_name : null
}

output "certmanager_vault_issuer" {
  description = "Vault-backed ClusterIssuer name"
  value       = var.certmanager_vault_issuer_enabled ? var.certmanager_vault_issuer_name : null
}
