// DEPLOY VAULT SECRETS STORE CSI DRIVER
resource "helm_release" "csi" {
  count            =  var.csi_enabled ? 1 : 0
  name             = "secrets-store-csi-driver"
  namespace        = "vault"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart            = "secrets-store-csi-driver "
  version          = "1.4.0"
  atomic           = true
  timeout          = 240

  depends_on = [
    vault_kubernetes_auth_backend_role.backend_role
  ]

}
