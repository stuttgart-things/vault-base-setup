// CREATE NAMESPACE!?

// CREATE SERVICE-ACCOUNT
resource "kubernetes_manifest" "service_account" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = each.value["name"]
      "namespace" = each.value["namespace"]
    }

    "automountServiceAccountToken" = true
  }

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
    kubernetes_manifest.service_account
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
  path = each.value["name"]

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

  backend                = each.value["name"]
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

  backend                          = each.value["name"]
  role_name                        = each.value["name"]
  bound_service_account_names      = [each.value["name"]]
  bound_service_account_namespaces = [each.value["namespace"]]
  token_ttl                        = each.value["token_ttl"]
  token_policies                   = each.value["token_policies"]

  depends_on = [
    vault_kubernetes_auth_backend_config.kubernetes
  ]

}

// KUBECONFIG FILE HANDLING
data "local_file" "input" {
  filename = var.kubeconfig_path
}

locals {
  kubeconfig = yamldecode(file(var.kubeconfig_path))
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
}
