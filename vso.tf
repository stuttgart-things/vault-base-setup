// DEPLOY VAULT SECRETS OPERATOR
resource "helm_release" "vso" {
  count            = var.vso_enabled ? 1 : 0
  name             = "vault-secrets-operator"
  namespace        = var.namespace_vso
  create_namespace = true
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  version          = "0.10.0"
  atomic           = true
  timeout          = 240

  depends_on = [
    vault_kubernetes_auth_backend_role.backend_role
  ]

}

// DEPLOY VAULT CONNECTION
resource "kubernetes_manifest" "vault_connection" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
    if var.vso_enabled
  }

  manifest = yamldecode(templatefile(
    "${path.module}/templates/vault-connection.tpl",
    {
      "name"       = each.value["name"]
      "namespace"  = each.value["namespace"]
      "vault_addr" = var.vault_addr
    }
  ))

  depends_on = [helm_release.vso]
}

// DEPLOY VAULT AUTH
resource "kubernetes_manifest" "vault_auth" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
    if var.vso_enabled
  }

  manifest = yamldecode(templatefile(
    "${path.module}/templates/vault-auth.tpl",
    {
      "name"         = each.value["name"]
      "namespace"    = each.value["namespace"]
      "cluster_name" = var.cluster_name
    }
  ))
  depends_on = [kubernetes_manifest.vault_connection]
}
