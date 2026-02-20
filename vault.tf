// DEPLOY VAULT SERVER
resource "helm_release" "vault" {
  count            = var.vault_enabled ? 1 : 0
  name             = "vault"
  namespace        = var.namespace_vault
  create_namespace = true
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = "0.29.1"
  atomic           = true
  timeout          = 240

  values = [yamlencode({
    server = {
      dev = {
        enabled = var.vault_dev_mode
      }
    }
    injector = {
      enabled = var.vault_injector_enabled
    }
    csi = {
      enabled = var.vault_csi_enabled
    }
  })]
}
