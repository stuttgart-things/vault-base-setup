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
  default     = "~/.kube/config"
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
