output "role_id" {
  description = "Output of role id"
  value = [
    for role in vault_approle_auth_backend_role.approle : role.role_id
  ]
}

output "secret_id" {
  description = "Output of secret id"
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
