variable "cluster" {
  type = object({
    name        = string
    host        = string
    config_path = string
    apps = list(object({
      namespace       = string
      service_account = string
    }))
    ca_secret_name      = string
    ca_secret_namespace = string
  })
}

variable "global_policies" {
  type = list(string)
}
