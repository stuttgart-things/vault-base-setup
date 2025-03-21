terraform {
  required_version = ">= 1.10.5"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.21.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}

provider "kubernetes" {
  config_context = var.context
  config_path    = var.kubeconfig_path
}

provider "kubectl" {
  config_context = var.context
  config_path    = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_context = var.context
    config_path    = var.kubeconfig_path
  }
}

provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = var.skip_tls_verify
}
