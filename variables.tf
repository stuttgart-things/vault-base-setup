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

variable "createDefaultAdminPolicy" { default = false }
variable "enableUserPass" { default = false }
variable "enableApproleAuth" { default = false }


variable "approle_roles" {
  type = list(object({
    name         = string
    token_policies = list(string)
  }))
  default     = []
  description = "A list of approle definitions"
}

variable "userPassPath" { default = "userpass" }
variable "user_list" {
  type = list(object({
    path         = string
    data_json   = string
  }))
  default     = []
  description = "A list of users"
}