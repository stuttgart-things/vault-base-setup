// ALLOW READING KVV2 OF ALL K8S CLUSTERS
resource "vault_policy" "kvv2" {

  for_each = {
    for policy in var.kv_policies :
    policy.name => policy
  }

  name   = each.value["name"]
  policy = each.value["capabilities"]
}

// CREATE ADMIN POLICY
resource "vault_policy" "admin" {
  count = (var.createDefaultAdminPolicy) ? 1 : 0

  name   = "admin"
  policy = file("${path.module}/templates/admin.hcl")
}