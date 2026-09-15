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

  role_name      = each.value.name
  token_policies = each.value.token_policies

  // A VALUE SET ON THE ROLE WINS; UNSET FALLS BACK TO THE MODULE-WIDE VARIABLE.
  // Explicit null checks, not coalesce(): coalesce() fails outright when a caller
  // has set the module-wide variable to null as well.
  //
  // token_ttl has no module-wide variable. Unset leaves it to the provider (0,
  // i.e. the auth mount's default lease) — exactly as before it was settable.
  token_ttl              = each.value.token_ttl
  secret_id_ttl          = each.value.secret_id_ttl != null ? each.value.secret_id_ttl : var.secret_id_ttl
  token_max_ttl          = each.value.token_max_ttl != null ? each.value.token_max_ttl : var.token_max_ttl
  secret_id_num_uses     = each.value.secret_id_num_uses != null ? each.value.secret_id_num_uses : var.secret_id_num_uses
  token_explicit_max_ttl = each.value.token_explicit_max_ttl != null ? each.value.token_explicit_max_ttl : var.token_explicit_max_ttl
  token_num_uses         = each.value.token_num_uses != null ? each.value.token_num_uses : var.token_num_uses
  token_period           = each.value.token_period != null ? each.value.token_period : var.token_period
}

// ONE SECRET ID PER ROLE, UNLESS THE ROLE OPTS OUT (create_secret_id = false).
//
// KEYS COME FROM THE INPUT VARIABLE, NOT FROM vault_approle_auth_backend_role.approle.
// Keys derived from resource attributes are unknown on the `terraform import` code
// path, which failed with "Invalid for_each argument" even for an empty role list
// (#42). The state keys are the role names either way, so nothing moves.
//
// OPTING AN EXISTING ROLE OUT DESTROYS ITS SECRET ID. Terraform removes the
// instance, and removing a secret_id revokes it — whoever logs in with it is locked
// out. Opt out only for a role whose secret_id this module never minted (e.g. one
// adopted with an import block), or once its consumers use a different secret_id.
resource "vault_approle_auth_backend_role_secret_id" "approle_secret" {
  for_each = {
    for role in var.approle_roles :
    role.name => role
    if role.create_secret_id
  }

  backend   = vault_approle_auth_backend_role.approle[each.key].backend
  role_name = vault_approle_auth_backend_role.approle[each.key].role_name
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
