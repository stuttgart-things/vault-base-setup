# function enables kv v2 secrets engine
resource "vault_mount" "kvv2" {

  for_each = {
    for mount in var.secret_engines :
    mount.path => mount
  }

  path = each.value["path"]

  type        = "kv-v2" # type of backend
  description = each.value["description"]

}

# writes data to kv store
resource "vault_generic_secret" "kvv2" {
  depends_on = [vault_mount.kvv2]

  for_each = {
    for mount in var.secret_engines :
    mount.path => mount
  }

  path = "${each.value["path"]}/${each.value["name"]}"
  data_json = each.value["data_json"]

}