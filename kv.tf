// CREATE A SECRET ENGINE
resource "vault_mount" "kvv2" {
  path        = format("kvv2-%s", var.cluster.name)
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount for ${var.cluster.name}"
}
