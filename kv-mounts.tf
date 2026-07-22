locals {
  // ONE MOUNT PER DISTINCT PATH.
  // Several secret_engines entries may share a path — that is the whole point of
  // keying secrets separately below. Deduplicate here, keeping the first entry
  // seen for a path as the source of its description.
  kv_mounts = {
    for path in distinct([for engine in var.secret_engines : engine.path]) :
    path => [for engine in var.secret_engines : engine if engine.path == path][0]
  }

  // ONE SECRET PER PATH+NAME.
  // Keying on path alone made two secrets in the same mount a hard
  // "Duplicate object key" error, which forced one mount per secret.
  kv_secrets = {
    for engine in var.secret_engines :
    "${engine.path}/${engine.name}" => engine
  }
}

# FUNCTION ENABLES KV V2 SECRETS ENGINE
resource "vault_mount" "kvv2" {

  for_each = local.kv_mounts

  path = each.key

  type        = "kv-v2" # type of backend
  description = each.value["description"]

}

# WRITES DATA TO KV STORE
resource "vault_generic_secret" "kvv2" {
  depends_on = [vault_mount.kvv2]

  for_each = local.kv_secrets

  path      = each.key
  data_json = each.value["data_json"]
}
