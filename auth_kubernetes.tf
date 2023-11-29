# FETCH THE KUBERNETES CLUSTER CA CERTIFICATE
data "kubernetes_secret" "ca_secret" {
  metadata {
    name      = var.cluster.ca_secret_name
    namespace = var.cluster.ca_secret_namespace
  }
}

# ENABLE THE KUBERNETES AUTH METHOD
resource "vault_auth_backend" "kubernetes" {
  path = var.cluster.name
  type = "kubernetes"
}

# CONFIGURE THE KUBERNETES METHOD USING THE K8S CLUSTER CA CERTIFICATE
resource "vault_kubernetes_auth_backend_config" "kubernetes_config" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.cluster.host
  kubernetes_ca_cert     = data.kubernetes_secret.ca_secret.data["tls.crt"]
  disable_iss_validation = "true"
  disable_local_ca_jwt   = "true" # allows auth for other clusters
}

# CREATE A ROLE THAT ACCEPTS THE GIVEN APP SA AND NAMESPACE
resource "vault_kubernetes_auth_backend_role" "apps" {
  backend = vault_auth_backend.kubernetes.path
  token_policies = concat(
    [
      # TODO: COME UP WITH A BETTER POLICY CONCEPT
      # VAULT_POLICY.MANAGE_KVV2.NAME,
      vault_policy.read_kvv2.name,
    ],
    var.global_policies
  )

  role_name                        = "read-global-and-local-kvv2"
  bound_service_account_names      = var.cluster.apps[*].service_account
  bound_service_account_namespaces = var.cluster.apps[*].namespace
}
