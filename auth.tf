// ENABLE THE APPROLE AUTH METHOD
resource "vault_auth_backend" "approle" {
  count = (var.enableApproleAuth) ? 1 : 0
  type  = "approle"
}

// CREATE APPROLE AUTH BACKEND ROLE
resource "vault_approle_auth_backend_role" "approle" {
  backend    = "approle"
  depends_on = [vault_auth_backend.approle]

  for_each = {
    for role in var.approle_roles :
    role.name => role
  }

  role_name      = each.value["name"]
  token_policies = each.value["token_policies"]

  secret_id_ttl          = var.secret_id_ttl
  token_max_ttl          = var.token_max_ttl
  secret_id_num_uses     = var.secret_id_num_uses
  token_explicit_max_ttl = var.token_explicit_max_ttl
  token_num_uses         = var.token_num_uses
  token_period           = var.token_period
}

resource "vault_approle_auth_backend_role_secret_id" "approle_secret" {

  depends_on = [vault_approle_auth_backend_role.approle]
  for_each = {
    for role in vault_approle_auth_backend_role.approle :
    role.role_name => role
  }

  backend   = each.value["backend"]
  role_name = each.value["role_name"]
}


// ENABLE USERPASS AUTH METHOD
resource "vault_auth_backend" "userpass" {
  count = (var.enableUserPass) ? 1 : 0
  path  = var.userPassPath
  type  = "userpass"
}

// CREATE A USER
resource "vault_generic_endpoint" "client_userpass_password" {
  depends_on           = [vault_auth_backend.userpass]
  ignore_absent_fields = true

  for_each = {
    for user in var.user_list :
    user.path => user
  }

  path      = each.value["path"]
  data_json = each.value["data_json"]

}
