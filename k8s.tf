// CREATE NAMESPACE!?

// CREATE SERVICE-ACCOUNT
// Deliberately not kubernetes_manifest: that resource performs a server-side
// lookup during *plan*, so any `terraform plan` without cluster access fails —
// which rules out plan-only CI pipelines.
resource "kubernetes_service_account_v1" "vault" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  metadata {
    name      = each.value["name"]
    namespace = each.value["namespace"]
  }

  automount_service_account_token = true

}

// CREATE SERVICE-ACCOUNT SECRET
resource "kubernetes_secret" "vault" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  metadata {
    name      = each.value["name"]
    namespace = each.value["namespace"]
    annotations = {
      "kubernetes.io/service-account.name"      = each.value["name"]
      "kubernetes.io/service-account.namespace" = each.value["namespace"]
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [
    kubernetes_service_account_v1.vault
  ]

}

// CREATE CLUSTER-ROLE-BINDING
resource "kubernetes_cluster_role_binding" "vault" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  metadata {
    name = each.value["name"]
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = each.value["name"]
    namespace = each.value["namespace"]
  }

  depends_on = [
    kubernetes_secret.vault
  ]

}

// CREATE KUBERNETES BACKEND
resource "vault_auth_backend" "kubernetes" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  type = "kubernetes"
  path = "${var.cluster_name}-${each.value["name"]}"

  depends_on = [
    kubernetes_secret.vault
  ]

}

// CREATE KUBERNETES BACKEND CONFIG
resource "vault_kubernetes_auth_backend_config" "kubernetes" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  backend                = "${var.cluster_name}-${each.value["name"]}"
  kubernetes_host        = local.kubeconfig.clusters[0].cluster.server
  kubernetes_ca_cert     = data.kubernetes_secret.vault[each.value["name"]].data["ca.crt"]
  token_reviewer_jwt     = data.kubernetes_secret.vault[each.value["name"]].data.token
  disable_iss_validation = "true"
  disable_local_ca_jwt   = "true"

  depends_on = [
    vault_auth_backend.kubernetes
  ]

}

// CREATE BACKEND ROLE
resource "vault_kubernetes_auth_backend_role" "backend_role" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  backend   = "${var.cluster_name}-${each.value["name"]}"
  role_name = each.value["name"]

  // DEFAULTS TO THE SERVICEACCOUNT THIS MODULE CREATES, BUT CAN ADMIT AN EXISTING ONE
  bound_service_account_names = (
    each.value["bound_service_account_names"] != null
    ? each.value["bound_service_account_names"]
    : [each.value["name"]]
  )
  bound_service_account_namespaces = (
    each.value["bound_service_account_namespaces"] != null
    ? each.value["bound_service_account_namespaces"]
    : [each.value["namespace"]]
  )

  token_ttl      = each.value["token_ttl"]
  token_policies = each.value["token_policies"]

  depends_on = [
    vault_kubernetes_auth_backend_config.kubernetes
  ]

}

// VARIABLES
variable "kubeconfig_content" {
  description = "Kubeconfig content as string (alternative to kubeconfig_path)"
  type        = string
  default     = null
  sensitive   = true
}

// VALIDATION
locals {
  # Ensure exactly one option is provided
  kubeconfig_options_count = (
    (var.kubeconfig_path != null ? 1 : 0) +
    (var.kubeconfig_content != null ? 1 : 0)
  )
}

resource "null_resource" "validate_kubeconfig_input" {
  lifecycle {
    precondition {
      condition     = local.kubeconfig_options_count == 1
      error_message = "Exactly one of 'kubeconfig_path' or 'kubeconfig_content' must be provided."
    }
  }
}

// KUBECONFIG FILE HANDLING
data "local_file" "kubeconfig" {
  count    = var.kubeconfig_path != null ? 1 : 0
  filename = var.kubeconfig_path
}

locals {
  # Use either file content or provided string
  kubeconfig_raw = var.kubeconfig_path != null ? data.local_file.kubeconfig[0].content : var.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)
}

data "kubernetes_secret" "vault" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  metadata {
    name      = each.value["name"]
    namespace = each.value["namespace"]
  }

  depends_on = [
    kubernetes_secret.vault
  ]

}
