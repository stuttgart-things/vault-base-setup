terraform {
  required_version = ">= 1.10.0"

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
      version = "2.7.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

provider "kubernetes" {
  config_context = var.kubeconfig_content == null ? var.context : null
  config_path    = var.kubeconfig_path

  host                   = var.kubeconfig_content != null ? local.kubeconfig.clusters[0].cluster.server : null
  cluster_ca_certificate = var.kubeconfig_content != null ? base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"]) : null
  client_certificate     = var.kubeconfig_content != null ? base64decode(local.kubeconfig.users[0].user["client-certificate-data"]) : null
  client_key             = var.kubeconfig_content != null ? base64decode(local.kubeconfig.users[0].user["client-key-data"]) : null
}

provider "kubectl" {
  config_context   = var.kubeconfig_content == null ? var.context : null
  config_path      = var.kubeconfig_path
  load_config_file = var.kubeconfig_content == null

  host                   = var.kubeconfig_content != null ? local.kubeconfig.clusters[0].cluster.server : null
  cluster_ca_certificate = var.kubeconfig_content != null ? base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"]) : null
  client_certificate     = var.kubeconfig_content != null ? base64decode(local.kubeconfig.users[0].user["client-certificate-data"]) : null
  client_key             = var.kubeconfig_content != null ? base64decode(local.kubeconfig.users[0].user["client-key-data"]) : null
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_content == null ? var.context : null

    host                   = var.kubeconfig_content != null ? local.kubeconfig.clusters[0].cluster.server : null
    cluster_ca_certificate = var.kubeconfig_content != null ? base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"]) : null
    client_certificate     = var.kubeconfig_content != null ? base64decode(local.kubeconfig.users[0].user["client-certificate-data"]) : null
    client_key             = var.kubeconfig_content != null ? base64decode(local.kubeconfig.users[0].user["client-key-data"]) : null
  }
}

provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = var.skip_tls_verify
}
