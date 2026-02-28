// VALIDATE CERT-MANAGER BOOTSTRAP CONFIGURATION
resource "null_resource" "validate_certmanager_bootstrap" {
  count = var.certmanager_bootstrap_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.certmanager_enabled
      error_message = "certmanager_enabled must be true when certmanager_bootstrap_enabled is true."
    }
  }
}

// VALIDATE VAULT CLUSTERISSUER CONFIGURATION
resource "null_resource" "validate_certmanager_vault_issuer" {
  count = var.certmanager_vault_issuer_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.pki_enabled
      error_message = "pki_enabled must be true when certmanager_vault_issuer_enabled is true."
    }
    precondition {
      condition     = var.certmanager_vault_issuer_pki_role != ""
      error_message = "certmanager_vault_issuer_pki_role must be set when certmanager_vault_issuer_enabled is true."
    }
  }
}

// DEPLOY CERT-MANAGER
resource "helm_release" "cert_manager" {
  count            = var.certmanager_enabled ? 1 : 0
  name             = "cert-manager"
  namespace        = var.certmanager_namespace
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.certmanager_chart_version
  wait             = true
  timeout          = 600

  values = [yamlencode({
    crds = {
      enabled = true
    }
  })]
}

// SELF-SIGNED CLUSTERISSUER (BOOTSTRAP)
resource "kubectl_manifest" "selfsigned_clusterissuer" {
  count = var.certmanager_bootstrap_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.certmanager_selfsigned_issuer_name
    }
    spec = {
      selfSigned = {}
    }
  })

  depends_on = [helm_release.cert_manager]
}

// BOOTSTRAP CA CERTIFICATE
resource "kubectl_manifest" "bootstrap_ca_certificate" {
  count = var.certmanager_bootstrap_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.certmanager_bootstrap_ca_name
      namespace = var.certmanager_namespace
    }
    spec = {
      isCA       = true
      commonName = var.certmanager_bootstrap_ca_common_name
      secretName = var.certmanager_bootstrap_ca_secret_name
      duration   = var.certmanager_bootstrap_ca_duration
      privateKey = {
        algorithm = "ECDSA"
        size      = 256
      }
      issuerRef = {
        name  = var.certmanager_selfsigned_issuer_name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  })

  depends_on = [kubectl_manifest.selfsigned_clusterissuer]
}

// BOOTSTRAP CA CLUSTERISSUER
resource "kubectl_manifest" "bootstrap_ca_clusterissuer" {
  count = var.certmanager_bootstrap_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.certmanager_bootstrap_ca_issuer_name
    }
    spec = {
      ca = {
        secretName = var.certmanager_bootstrap_ca_secret_name
      }
    }
  })

  depends_on = [kubectl_manifest.bootstrap_ca_certificate]
}

// READ BOOTSTRAP CA SECRET (FOR CABUNDLE)
data "kubernetes_secret" "bootstrap_ca" {
  count = var.certmanager_bootstrap_enabled && var.certmanager_vault_issuer_enabled ? 1 : 0

  metadata {
    name      = var.certmanager_bootstrap_ca_secret_name
    namespace = var.certmanager_namespace
  }

  depends_on = [kubectl_manifest.bootstrap_ca_certificate]
}

locals {
  certmanager_vault_issuer_effective_server = (
    var.certmanager_vault_issuer_server != ""
    ? var.certmanager_vault_issuer_server
    : var.vault_addr
  )

  certmanager_vault_issuer_effective_ca_bundle = (
    var.certmanager_vault_issuer_ca_bundle != ""
    ? var.certmanager_vault_issuer_ca_bundle
    : (
      var.certmanager_bootstrap_enabled && var.certmanager_vault_issuer_enabled
      ? (
        data.kubernetes_secret.bootstrap_ca[0].data["ca.crt"] != null
        ? base64encode(data.kubernetes_secret.bootstrap_ca[0].data["ca.crt"])
        : null
      )
      : null
    )
  )
}

// VAULT TOKEN FOR CERT-MANAGER
resource "vault_token" "certmanager" {
  count     = var.certmanager_vault_issuer_enabled ? 1 : 0
  policies  = [var.pki_policy_name]
  ttl       = var.certmanager_vault_token_ttl
  no_parent = true
  renewable = true

  depends_on = [vault_policy.pki]
}

// ORDERING BRIDGE: ENSURES CERT-MANAGER IS READY BEFORE CREATING SECRET
resource "null_resource" "certmanager_ready" {
  count      = var.certmanager_enabled && var.certmanager_vault_issuer_enabled ? 1 : 0
  depends_on = [helm_release.cert_manager]
}

moved {
  from = kubernetes_secret.certmanager_vault_token
  to   = kubernetes_secret_v1.certmanager_vault_token
}

// KUBERNETES SECRET FOR VAULT TOKEN
resource "kubernetes_secret_v1" "certmanager_vault_token" {
  count = var.certmanager_vault_issuer_enabled ? 1 : 0

  metadata {
    name      = var.certmanager_vault_token_secret_name
    namespace = var.certmanager_vault_issuer_namespace
  }

  data = {
    token = vault_token.certmanager[0].client_token
  }

  depends_on = [null_resource.certmanager_ready]
}

// VAULT-BACKED CLUSTERISSUER
resource "kubectl_manifest" "vault_clusterissuer" {
  count = var.certmanager_vault_issuer_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.certmanager_vault_issuer_name
    }
    spec = {
      vault = merge(
        {
          path   = "${var.pki_path}/sign/${var.certmanager_vault_issuer_pki_role}"
          server = local.certmanager_vault_issuer_effective_server
          auth = {
            tokenSecretRef = {
              name = var.certmanager_vault_token_secret_name
              key  = "token"
            }
          }
        },
        local.certmanager_vault_issuer_effective_ca_bundle != null ? {
          caBundle = local.certmanager_vault_issuer_effective_ca_bundle
        } : {}
      )
    }
  })

  depends_on = [
    kubernetes_secret_v1.certmanager_vault_token,
    null_resource.validate_certmanager_vault_issuer,
  ]
}
