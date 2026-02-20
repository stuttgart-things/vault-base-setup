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
  }))
  default     = []
  description = "A list of k8s_auth objects"
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

variable "vault_dev_mode" {
  description = "Enable Vault dev mode"
  type        = bool
  default     = true
}

variable "vault_injector_enabled" {
  description = "Enable Vault injector"
  type        = bool
  default     = false
}

variable "vault_csi_enabled" {
  description = "Enable Vault CSI provider"
  type        = bool
  default     = true
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
    name             = string
    allowed_domains  = list(string)
    allow_subdomains = bool
    max_ttl          = string
    ttl              = optional(string)
    allow_bare_domains = optional(bool, false)
    key_type         = optional(string)
    key_bits         = optional(number)
  }))
  default = []
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
