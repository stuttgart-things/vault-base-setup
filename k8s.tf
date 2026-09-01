// CREATE NAMESPACE!?

// TWO SERVICEACCOUNTS, AND THE SPLIT IS THE POINT.
//
// A Kubernetes auth mount needs two different identities, and they used to be
// the same one here:
//
//   the REVIEWER  whose JWT Vault presents to the TokenReview API to validate
//                 somebody else's token. Needs system:auth-delegator, which is
//                 the right to review ANY token in the cluster.
//   the LOGIN SA  the workload that authenticates. Needs nothing at all — it
//                 only has to be admitted by bound_service_account_names.
//
// Giving the login SA system:auth-delegator hands a workload — typically
// cert-manager — the ability to validate every token in the cluster, to solve a
// problem it is not part of. One reviewer, in kube-system, shared by every
// mount, is the shape the VM pipeline's CreateVaultKubernetesAuth already uses.
locals {
  // Resolve each backend's reviewer, then collapse to the distinct set: several
  // mounts naming the same reviewer must not each try to create it.
  k8s_auth_reviewer_of = {
    for auth in var.k8s_auths :
    auth.name => {
      name      = coalesce(auth.reviewer_name, var.k8s_auth_reviewer_name)
      namespace = coalesce(auth.reviewer_namespace, var.k8s_auth_reviewer_namespace)
    }
  }

  k8s_auth_reviewer_key = {
    for name, r in local.k8s_auth_reviewer_of :
    name => "${r.namespace}/${r.name}"
  }

  // distinct() is load-bearing: a `for` producing a map REJECTS duplicate keys
  // rather than collapsing them, and the normal case is several mounts sharing
  // one reviewer -- cert-manager and external-secrets on the same cluster.
  // Without it: "Two different items produced the key kube-system/
  // vault-auth-reviewer in this 'for' expression."
  k8s_auth_reviewers = {
    for r in distinct(values(local.k8s_auth_reviewer_of)) :
    "${r.namespace}/${r.name}" => r
  }
}

// CREATE THE REVIEWER SERVICE-ACCOUNT
// Deliberately not kubernetes_manifest: that resource performs a server-side
// lookup during *plan*, so any `terraform plan` without cluster access fails —
// which rules out plan-only CI pipelines.
resource "kubernetes_service_account_v1" "reviewer" {

  for_each = local.k8s_auth_reviewers

  metadata {
    name      = each.value["name"]
    namespace = each.value["namespace"]
  }

  // No pod ever runs as this ServiceAccount. Its only purpose is the token
  // Secret below, which Vault reads once at configure time.
  automount_service_account_token = false

}

// CREATE THE REVIEWER'S TOKEN SECRET
// This is the JWT Vault presents to TokenReview, and the cluster CA it verifies
// the API server with. A long-lived SA token is exactly right here and nowhere
// else: Vault stores it in the mount config, so it cannot be re-minted per use.
resource "kubernetes_secret_v1" "reviewer" {

  for_each = local.k8s_auth_reviewers

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
    kubernetes_service_account_v1.reviewer
  ]

}

// GRANT system:auth-delegator TO THE REVIEWER — AND ONLY THE REVIEWER
resource "kubernetes_cluster_role_binding" "reviewer" {

  for_each = local.k8s_auth_reviewers

  metadata {
    // Namespace-qualified: two reviewers of the same name in different
    // namespaces are legal, and a ClusterRoleBinding name is cluster-scoped.
    name = "${each.value["namespace"]}-${each.value["name"]}-auth-delegator"
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
    kubernetes_secret_v1.reviewer
  ]

}

// CREATE THE LOGIN SERVICE-ACCOUNT
// The identity that authenticates against the mount. It holds NO cluster
// permissions from this module, and it no longer has a static token Secret: a
// caller using it mints short-lived tokens through the TokenRequest API.
//
// Still created unconditionally, including when bound_service_account_names
// admits somebody else's ServiceAccount instead. Left that way on purpose —
// making it conditional is a second behaviour change, and this one is about the
// reviewer.
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

// CREATE KUBERNETES BACKEND
resource "vault_auth_backend" "kubernetes" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  type = "kubernetes"
  path = "${var.cluster_name}-${each.value["name"]}"

  depends_on = [
    kubernetes_secret_v1.reviewer
  ]

}

// CREATE KUBERNETES BACKEND CONFIG
resource "vault_kubernetes_auth_backend_config" "kubernetes" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  backend         = "${var.cluster_name}-${each.value["name"]}"
  kubernetes_host = local.kubeconfig.clusters[0].cluster.server

  // Both come from the REVIEWER, not from the ServiceAccount that logs in.
  // The JWT is what Vault presents to TokenReview; the CA is how it verifies
  // the API server it presents it to.
  kubernetes_ca_cert = data.kubernetes_secret_v1.reviewer[local.k8s_auth_reviewer_key[each.value["name"]]].data["ca.crt"]
  token_reviewer_jwt = data.kubernetes_secret_v1.reviewer[local.k8s_auth_reviewer_key[each.value["name"]]].data.token

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

// READ BACK THE REVIEWER'S TOKEN AND THE CLUSTER CA
// A data source rather than the resource's own attributes: the controller
// populates .data asynchronously after the Secret is created, so the resource
// can be known while the token is still empty.
data "kubernetes_secret_v1" "reviewer" {

  for_each = local.k8s_auth_reviewers

  metadata {
    name      = each.value["name"]
    namespace = each.value["namespace"]
  }

  depends_on = [
    kubernetes_secret_v1.reviewer
  ]

}
