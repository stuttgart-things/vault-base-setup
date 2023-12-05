terraform {
  required_version = ">= 1.6.5"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.21.0"
    }
  }
}
