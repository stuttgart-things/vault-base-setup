// ALLOW MANAGING KVV2 OF THIS K8S CLUSTER
resource "vault_policy" "manage_kvv2" {
  name = format("%s-manage-kvv2", var.cluster.name)

  policy = templatefile("${path.module}/templates/manage_kvv2.tpl", {
    kvv2_mount_path = vault_mount.kvv2.path
  })
}

// ALLOW READING KVV2 OF THIS K8S CLUSTER
resource "vault_policy" "read_kvv2" {
  name = format("%s-read-kvv2", var.cluster.name)

  policy = templatefile("${path.module}/templates/read_kvv2.tpl", {
    kvv2_mount_path = vault_mount.kvv2.path
  })
}
