variable "secret_engines" {
  type = list(object({
    name        = string
    path        = string
    description = string
    data_json   = string
  }))
  default     = []
  description = "A list of secret path objects"
}

variable "kv_policies" {
  type = list(object({
    name         = string
    capabilities = string
  }))
  default     = []
  description = "A list of kv policies"
}

variable "k8s_auths" {
  type = list(object({
    name           = string
    namespace      = string
    token_policies = list(string)
    token_ttl      = number

    # Which ServiceAccounts may log in through this mount. Defaults to the
    # ServiceAccount this module creates ([name] / [namespace]). Override to
    # admit an existing ServiceAccount instead — e.g. cert-manager's, which is
    # Helm-managed and cannot be recreated here.
    bound_service_account_names      = optional(list(string))
    bound_service_account_namespaces = optional(list(string))

    # The ServiceAccount whose JWT Vault presents to TokenReview. Falls back to
    # k8s_auth_reviewer_name / _namespace, and normally should — one reviewer
    # per cluster is the point. Override only where a mount has to be reviewed
    # by a different identity.
    #
    # NOT the ServiceAccount that logs in. This one holds system:auth-delegator,
    # the right to review ANY token in the cluster, which is not a right a
    # workload should hold in order to authenticate itself.
    reviewer_name      = optional(string)
    reviewer_namespace = optional(string)
  }))
  default     = []
  description = "A list of k8s_auth objects"
}

variable "k8s_auth_reviewer_name" {
  description = "ServiceAccount whose JWT Vault presents to TokenReview. Holds system:auth-delegator and is shared by every Kubernetes auth mount unless an entry overrides it."
  type        = string
  default     = "vault-auth-reviewer"
}

variable "k8s_auth_reviewer_namespace" {
  description = "Namespace of the token reviewer ServiceAccount. kube-system by default: it is a cluster-wide identity, not a tenant's."
  type        = string
  default     = "kube-system"
}

# Set false on a cluster built by the VM pipeline: blueprints
# CreateVaultKubernetesAuth already places the ServiceAccount, its SA-token
# Secret and the ClusterRoleBinding under exactly these names, and two owners
# for one identity is not a conflict Terraform can resolve -- it fails with
# `serviceaccounts "vault-auth-reviewer" already exists`.
#
# The module then only READS the reviewer's Secret. The names line up because
# the pipeline names that Secret after the ServiceAccount too.
variable "k8s_auth_reviewer_create" {
  description = "Create the token reviewer ServiceAccount, its SA-token Secret and its system:auth-delegator binding. Set false to use a reviewer that already exists — e.g. one the VM pipeline created."
  type        = bool
  default     = true
}

variable "kubeconfig_path" {
  type        = string
  default     = null
  description = "kubeconfig path"
}

variable "context" {
  type        = string
  default     = "default"
  description = "kube cluster context"
}

variable "approle_roles" {
  type = list(object({
    name           = string
    token_policies = list(string)
  }))
  default     = []
  description = "A list of approle definitions"
}

variable "userPassPath" {
  type        = string
  default     = "userpass"
  description = "userpass"
}

variable "user_list" {
  type = list(object({
    path      = string
    data_json = string
  }))
  default     = []
  description = "A list of users"
}

variable "secret_id_ttl" {
  type        = number
  default     = 0
  description = "The number of seconds after which any SecretID expires"
}

variable "token_max_ttl" {
  type        = number
  default     = 0
  description = "The maximum lifetime for generated tokens in number of seconds. Its current value will be referenced at renewal time."
}

variable "secret_id_num_uses" {
  type        = number
  default     = 0
  description = "The number of times any particular SecretID can be used to fetch a token from this AppRole, after which the SecretID will expire. A value of zero will allow unlimited uses."
}

variable "token_explicit_max_ttl" {
  type        = number
  default     = 0
  description = "If set, will encode an explicit max TTL onto the token in number of seconds. This is a hard cap even if token_ttl and token_max_ttl would otherwise allow a renewal."
}

variable "token_num_uses" {
  type        = number
  default     = 0
  description = "The period, if any, in number of seconds to set on the token."
}

variable "token_period" {
  type        = number
  default     = 0
  description = "If set, indicates that the token generated using this role should never expire. The token should be renewed within the duration specified by this value. At each renewal, the token's TTL will be set to the value of this field. Specified in seconds."
}

variable "csi_enabled" {
  description = "Enable secrets store csi driver"
  type        = bool
  default     = true
}

variable "namespace_csi" {
  description = "Namespace of secrets store csi driver"
  type        = string
  default     = "secrets-store-csi"
}

variable "cluster_name" {
  type        = string
  default     = false
  description = "cluster name"
}

variable "vso_enabled" {
  description = "Enable vault-secrets-operator"
  type        = bool
  default     = true
}

variable "namespace_vso" {
  description = "Namespace of vault-secrets-operator"
  type        = string
  default     = "vault-secrets-operator"
}

variable "enableApproleAuth" {
  description = "Enable approle auth"
  type        = bool
  default     = false
}

variable "createDefaultAdminPolicy" {
  description = "Create default admin policy"
  type        = bool
  default     = false
}

variable "enableUserPass" {
  description = "Enable user pass"
  type        = bool
  default     = false
}

variable "vault_addr" {
  type        = string
  default     = false
  description = "vault_addr"
}

variable "skip_tls_verify" {
  description = "Skip tls for vault"
  type        = bool
  default     = false
}

variable "vault_enabled" {
  description = "Enable Vault server deployment"
  type        = bool
  default     = false
}

variable "namespace_vault" {
  description = "Namespace for Vault server deployment"
  type        = string
  default     = "vault"
}

variable "vault_injector_enabled" {
  description = "Enable Vault injector"
  type        = bool
  default     = false
}

variable "vault_chart_repository" {
  description = "OCI Helm chart repository for Vault"
  type        = string
  default     = "oci://registry-1.docker.io/bitnamicharts/vault"
}

variable "vault_chart_version" {
  description = "Vault Helm chart version"
  type        = string
  default     = "1.9.0"
}

variable "vault_image_registry" {
  description = "Vault server image registry"
  type        = string
  default     = "ghcr.io"
}

variable "vault_image_repository" {
  description = "Vault server image repository"
  type        = string
  default     = "stuttgart-things/vault"
}

variable "vault_image_tag" {
  description = "Vault server image tag"
  type        = string
  default     = "1.20.2-debian-12-r2"
}

variable "vault_ingress_enabled" {
  description = "Enable ingress for Vault server"
  type        = bool
  default     = false
}

variable "vault_ingress_class" {
  description = "Ingress class name for Vault"
  type        = string
  default     = "nginx"
}

variable "vault_ingress_hostname" {
  description = "Hostname for Vault ingress"
  type        = string
  default     = ""
}

variable "vault_ingress_issuer_name" {
  description = "cert-manager issuer name for Vault ingress TLS"
  type        = string
  default     = ""
}

variable "vault_ingress_issuer_kind" {
  description = "cert-manager issuer kind (ClusterIssuer or Issuer)"
  type        = string
  default     = "ClusterIssuer"

  validation {
    condition     = contains(["ClusterIssuer", "Issuer"], var.vault_ingress_issuer_kind)
    error_message = "vault_ingress_issuer_kind must be either 'ClusterIssuer' or 'Issuer'."
  }
}

variable "vault_storage_class" {
  description = "Storage class for Vault persistent volumes"
  type        = string
  default     = ""
}

variable "vault_volume_permissions" {
  description = "Enable init container to fix volume permissions"
  type        = bool
  default     = true
}

variable "vault_injector_image_registry" {
  description = "Vault injector image registry"
  type        = string
  default     = "ghcr.io"
}

variable "vault_injector_image_repository" {
  description = "Vault injector image repository"
  type        = string
  default     = "stuttgart-things/vault-k8s"
}

variable "vault_injector_image_tag" {
  description = "Vault injector image tag"
  type        = string
  default     = "1.7.0-debian-12-r4"
}

variable "vault_os_shell_image_registry" {
  description = "OS shell image registry (used for volume permissions init container)"
  type        = string
  default     = "ghcr.io"
}

variable "vault_os_shell_image_repository" {
  description = "OS shell image repository"
  type        = string
  default     = "stuttgart-things/os-shell"
}

variable "vault_os_shell_image_tag" {
  description = "OS shell image tag"
  type        = string
  default     = "12-debian-12-r50"
}

variable "vault_wait" {
  description = "Whether to wait for Vault pods to be ready (set to false when using auto-unseal)"
  type        = bool
  default     = false
}

variable "vault_atomic" {
  description = "Whether to rollback Vault Helm release on failure"
  type        = bool
  default     = false
}

variable "vault_dev_mode" {
  description = "Run Vault in dev mode (auto-initialized, auto-unsealed, in-memory storage)"
  type        = bool
  default     = false
}

variable "vault_dev_root_token" {
  description = "Root token ID for Vault dev mode"
  type        = string
  default     = "root"
}

variable "vault_autounseal_enabled" {
  description = "Enable vault-autounseal deployment for automatic init and unseal"
  type        = bool
  default     = false
}

variable "vault_autounseal_chart_version" {
  description = "vault-autounseal Helm chart version"
  type        = string
  default     = "0.5.3"
}

variable "vault_autounseal_secret_shares" {
  description = "Number of key shares for Vault unseal"
  type        = number
  default     = 3
}

variable "vault_autounseal_secret_threshold" {
  description = "Number of key shares required to unseal Vault"
  type        = number
  default     = 2
}

variable "vault_gateway_enabled" {
  description = "Enable Gateway API HTTPRoute for Vault"
  type        = bool
  default     = false
}

variable "vault_gateway_hostname" {
  description = "Hostname for Vault Gateway API HTTPRoute"
  type        = string
  default     = ""
}

variable "vault_gateway_name" {
  description = "Name of the Gateway resource to attach the HTTPRoute to"
  type        = string
  default     = ""
}

variable "vault_gateway_namespace" {
  description = "Namespace of the Gateway resource"
  type        = string
  default     = "default"
}

variable "vault_gateway_section" {
  description = "Gateway listener section name (e.g. https, http)"
  type        = string
  default     = "https"
}

variable "pki_enabled" {
  description = "Enable Vault PKI secrets engine"
  type        = bool
  default     = false
}

variable "pki_path" {
  description = "Mount path for PKI secrets engine"
  type        = string
  default     = "pki"
}

variable "pki_common_name" {
  description = "Common name for the root CA certificate"
  type        = string
  default     = "example.com"
}

variable "pki_organization" {
  description = "Organization for the root CA certificate"
  type        = string
  default     = ""
}

variable "pki_country" {
  description = "Country for the root CA certificate"
  type        = string
  default     = ""
}

variable "pki_type" {
  description = "Type of root certificate to generate (internal or exported)"
  type        = string
  default     = "internal"
}

variable "pki_key_type" {
  description = "Key type for the CA (rsa or ec)"
  type        = string
  default     = "rsa"
}

variable "pki_key_bits" {
  description = "Key size in bits (2048, 4096 for RSA; 256, 384 for EC)"
  type        = number
  default     = 2048
}

variable "pki_root_ttl" {
  description = "TTL for the root CA certificate"
  type        = string
  default     = "87600h"
}

variable "pki_default_ttl_seconds" {
  description = "Default lease TTL for PKI secrets engine in seconds"
  type        = number
  default     = 3600
}

variable "pki_max_ttl_seconds" {
  description = "Max lease TTL for PKI secrets engine in seconds"
  type        = number
  default     = 315360000
}

variable "pki_policy_name" {
  description = "Name of the Vault policy for PKI access"
  type        = string
  default     = "pki-issue"
}

variable "pki_roles" {
  description = "List of PKI roles for certificate issuance"
  type = list(object({
    name               = string
    allowed_domains    = list(string)
    allow_subdomains   = bool
    max_ttl            = string
    ttl                = optional(string)
    allow_bare_domains = optional(bool, false)
    key_type           = optional(string)
    key_bits           = optional(number)
  }))
  default = []
}

# CERT-MANAGER VARIABLES
variable "certmanager_enabled" {
  description = "Deploy cert-manager via Helm"
  type        = bool
  default     = false
}

variable "certmanager_namespace" {
  description = "Namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "certmanager_chart_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.17.1"
}

# BOOTSTRAP CA VARIABLES
variable "certmanager_bootstrap_enabled" {
  description = "Create self-signed CA bootstrap chain for Vault ingress TLS"
  type        = bool
  default     = false
}

variable "certmanager_selfsigned_issuer_name" {
  description = "Name of the self-signed ClusterIssuer"
  type        = string
  default     = "selfsigned-issuer"
}

variable "certmanager_bootstrap_ca_name" {
  description = "Name of the bootstrap CA Certificate resource"
  type        = string
  default     = "bootstrap-ca"
}

variable "certmanager_bootstrap_ca_common_name" {
  description = "Common name for the bootstrap CA certificate"
  type        = string
  default     = "Bootstrap CA"
}

variable "certmanager_bootstrap_ca_secret_name" {
  description = "Secret name for the bootstrap CA key pair"
  type        = string
  default     = "bootstrap-ca-secret"
}

variable "certmanager_bootstrap_ca_duration" {
  description = "Duration (TTL) of the bootstrap CA certificate"
  type        = string
  default     = "87600h"
}

variable "certmanager_bootstrap_ca_issuer_name" {
  description = "Name of the bootstrap CA ClusterIssuer"
  type        = string
  default     = "bootstrap-ca-issuer"
}

# VAULT CLUSTERISSUER VARIABLES
variable "certmanager_vault_issuer_enabled" {
  description = "Create a Vault-backed ClusterIssuer in cert-manager"
  type        = bool
  default     = false
}

variable "certmanager_vault_issuer_name" {
  description = "Name of the Vault-backed ClusterIssuer"
  type        = string
  default     = "vault-pki"
}

variable "certmanager_vault_issuer_namespace" {
  description = "Namespace for the Vault token secret (must match cert-manager controller namespace)"
  type        = string
  default     = "cert-manager"
}

variable "certmanager_vault_issuer_pki_role" {
  description = "PKI role name cert-manager uses to issue certificates via Vault"
  type        = string
  default     = ""
}

variable "certmanager_vault_issuer_auth_method" {
  description = <<-EOT
    How the ClusterIssuer authenticates to Vault.

    "token" (default) creates a static vault_token and stores it in a Secret.
    Nothing renews that token — the Terraform provider only renews during an
    apply — so Vault auth breaks roughly certmanager_vault_token_ttl after every
    apply, while the ClusterIssuer keeps reporting Ready=True.

    "kubernetes" uses Vault Kubernetes auth: cert-manager mints a short-lived
    ServiceAccount token per request, so there is nothing to expire. Prefer it.
    Requires certmanager_vault_issuer_k8s_auth_mount and _k8s_auth_role.
  EOT
  type        = string
  default     = "token"

  validation {
    condition     = contains(["token", "kubernetes"], var.certmanager_vault_issuer_auth_method)
    error_message = "certmanager_vault_issuer_auth_method must be either \"token\" or \"kubernetes\"."
  }
}

variable "certmanager_vault_issuer_k8s_auth_mount" {
  description = "Vault Kubernetes auth mount path (without the /v1/auth/ prefix), e.g. \"my-cluster-certmanager\". Required when auth method is \"kubernetes\"."
  type        = string
  default     = ""
}

variable "certmanager_vault_issuer_k8s_auth_role" {
  description = "Vault Kubernetes auth role name. Required when auth method is \"kubernetes\"."
  type        = string
  default     = ""
}

variable "certmanager_vault_issuer_service_account" {
  description = "ServiceAccount cert-manager presents when logging in to Vault. Defaults to certmanager_vault_issuer_k8s_auth_role. Must be listed in the Vault role's bound_service_account_names."
  type        = string
  default     = ""
}

variable "certmanager_vault_issuer_create_tokenrequest_role" {
  description = <<-EOT
    Create the Role/RoleBinding letting the cert-manager controller mint tokens
    for the login ServiceAccount. cert-manager ships a tokenrequest Role scoped
    via resourceNames to its own "cert-manager" ServiceAccount only, so any other
    ServiceAccount needs this grant — without it issuance fails at runtime, not
    at apply time. Only used when auth method is "kubernetes".
  EOT
  type        = bool
  default     = true
}

variable "certmanager_vault_issuer_controller_service_account" {
  description = "Name of the cert-manager controller ServiceAccount that is granted TokenRequest access to the login ServiceAccount."
  type        = string
  default     = "cert-manager"
}

variable "certmanager_vault_token_ttl" {
  description = <<-EOT
    TTL for the Vault token used by cert-manager. Only used when
    certmanager_vault_issuer_auth_method is "token".

    Vault caps this at the token mount's max_lease_ttl, which defaults to 768h
    (32 days) — larger values are silently truncated rather than rejected, so
    raising this is not a way to avoid the expiry. Use auth_method "kubernetes"
    instead.
  EOT
  type        = string
  default     = "720h"

  validation {
    condition = (
      can(regex("^[0-9]+h$", var.certmanager_vault_token_ttl))
      ? tonumber(trimsuffix(var.certmanager_vault_token_ttl, "h")) <= 768
      : true
    )
    error_message = "certmanager_vault_token_ttl exceeds Vault's default token mount max_lease_ttl of 768h; a larger value would be silently truncated. Raise sys/auth/token/tune first, or use certmanager_vault_issuer_auth_method = \"kubernetes\"."
  }
}

variable "certmanager_vault_token_secret_name" {
  description = "Name of the Kubernetes secret storing the Vault token for cert-manager"
  type        = string
  default     = "vault-pki-token"
}

variable "certmanager_vault_issuer_server" {
  description = "Vault server URL for the ClusterIssuer. If empty, defaults to var.vault_addr."
  type        = string
  default     = ""
}

variable "certmanager_vault_issuer_ca_bundle" {
  description = "Base64-encoded CA bundle for the Vault ClusterIssuer. If empty, falls back to bootstrap CA (when available), then null."
  type        = string
  default     = ""
}

variable "certmanager_vault_issuer_policy_name" {
  description = "Vault policy name for the cert-manager token. If empty, defaults to var.pki_policy_name. Use this for cross-cluster setups where the policy already exists on the remote Vault."
  type        = string
  default     = ""
}

# Whether Helm should wait for resources to become ready
variable "vso_wait" {
  description = "Whether to wait for resources to be ready before marking the Helm release as successful."
  type        = bool
  default     = false
}

# Whether the Helm release should roll back automatically on failure
variable "vso_atomic" {
  description = "Whether to roll back the Helm release automatically on failure."
  type        = bool
  default     = false
}
