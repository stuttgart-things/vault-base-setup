// AUTO-WIRE VAULT INGRESS ISSUER FROM BOOTSTRAP CA
locals {
  vault_ingress_issuer_name = (
    var.certmanager_bootstrap_enabled && var.vault_ingress_issuer_name == ""
    ? var.certmanager_bootstrap_ca_issuer_name
    : var.vault_ingress_issuer_name
  )
}

// VALIDATE VAULT INGRESS CONFIGURATION
resource "null_resource" "validate_vault_ingress" {
  count = var.vault_enabled && var.vault_ingress_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.vault_ingress_hostname != ""
      error_message = "vault_ingress_hostname must be set when vault_ingress_enabled is true."
    }
    precondition {
      condition     = local.vault_ingress_issuer_name != ""
      error_message = "vault_ingress_issuer_name must be set when vault_ingress_enabled is true (or enable certmanager_bootstrap_enabled to auto-wire)."
    }
  }
}

// DEPLOY VAULT SERVER (BITNAMI)
resource "helm_release" "vault" {
  count            = var.vault_enabled ? 1 : 0
  name             = "vault"
  namespace        = var.namespace_vault
  create_namespace = true
  chart            = var.vault_chart_repository
  version          = var.vault_chart_version
  wait             = var.vault_wait
  atomic           = var.vault_atomic
  timeout          = 600

  values = [yamlencode(merge(
    {
      server = merge(
        {
          image = {
            registry   = var.vault_image_registry
            repository = var.vault_image_repository
            tag        = var.vault_image_tag
          }
          persistence = {
            storageClass = var.vault_storage_class
          }
        },
        var.vault_ingress_enabled ? {
          ingress = {
            enabled          = true
            ingressClassName = var.vault_ingress_class
            hostname         = var.vault_ingress_hostname
            tls              = true
            annotations = {
              (var.vault_ingress_issuer_kind == "ClusterIssuer"
                ? "cert-manager.io/cluster-issuer"
                : "cert-manager.io/issuer"
              ) = local.vault_ingress_issuer_name
            }
          }
        } : {}
      )
      global = {
        defaultStorageClass = var.vault_storage_class
        security = {
          allowInsecureImages = true
        }
      }
      injector = {
        enabled = var.vault_injector_enabled
        image = {
          registry   = var.vault_injector_image_registry
          repository = var.vault_injector_image_repository
          tag        = var.vault_injector_image_tag
        }
      }
      volumePermissions = {
        enabled = var.vault_volume_permissions
        image = {
          registry   = var.vault_os_shell_image_registry
          repository = var.vault_os_shell_image_repository
          tag        = var.vault_os_shell_image_tag
        }
      }
    }
  ))]

  depends_on = [
    null_resource.validate_vault_ingress,
    kubectl_manifest.bootstrap_ca_clusterissuer,
  ]
}

// DEPLOY VAULT AUTO-UNSEAL
resource "helm_release" "vault_autounseal" {
  count            = var.vault_enabled && var.vault_autounseal_enabled ? 1 : 0
  name             = "vault-autounseal"
  namespace        = var.namespace_vault
  create_namespace = true
  repository       = "https://pytoshka.github.io/vault-autounseal"
  chart            = "vault-autounseal"
  version          = var.vault_autounseal_chart_version

  values = [yamlencode({
    settings = {
      vault_url              = "http://vault-server.${var.namespace_vault}.svc:8200"
      vault_label_selector   = "app.kubernetes.io/component=server"
      vault_secret_shares    = var.vault_autounseal_secret_shares
      vault_secret_threshold = var.vault_autounseal_secret_threshold
    }
  })]

  depends_on = [helm_release.vault]
}

// DEPLOY VAULT HTTPROUTE (GATEWAY API)
resource "kubectl_manifest" "vault_httproute" {
  count = var.vault_enabled && var.vault_gateway_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "vault"
      namespace = var.namespace_vault
    }
    spec = {
      hostnames = [var.vault_gateway_hostname]
      parentRefs = [{
        name        = var.vault_gateway_name
        namespace   = var.vault_gateway_namespace
        sectionName = var.vault_gateway_section
      }]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "vault-server"
          port = 8200
        }]
      }]
    }
  })

  depends_on = [helm_release.vault]
}
