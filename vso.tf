// DEPLOY VAULT SECRETS OPERATOR
resource "helm_release" "vso" {
  count            =  1
  name             = "vault-secrets-operator"
  namespace        = "vault-secrets-operator"
  create_namespace = true
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  version          = "0.4.2"
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
  }

  manifest = yamldecode(templatefile(
    "${path.module}/templates/vault-connection.tpl",
    {
      "name" = each.value["name"]
      "namespace"= each.value["namespace"]
      "vault_addr" =  var.vault_addr
    }
  ))
  # depends_on = [helm_release.vso]
}

// DEPLOY VAULT AUTH
resource "kubernetes_manifest" "vault_auth" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  manifest = yamldecode(templatefile(
    "${path.module}/templates/vault-auth.tpl",
    {
      "name" = each.value["name"]
      "namespace"= each.value["namespace"]
    }
  ))
  depends_on = [kubernetes_manifest.vault_connection]
}
