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
