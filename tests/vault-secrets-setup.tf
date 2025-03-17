module "vault-secrets-setup" {
  source                   = "../vault-base-setup/"
  kubeconfig_path          = "/home/sthings/.kube/kind-helm-dev"
  vault_addr               = "https://vault.demo.sthings-vsphere.labul.sva.de"
  createDefaultAdminPolicy = true
  csi_enabled              = false
  vso_enabled              = false
  skip_tls_verify          = false
  context                  = "kind-helm-dev"
  cluster_name             = "kind-helm-dev"
  enableApproleAuth        = false
  secret_engines = [
    {
      path        = "apps"
      name        = "demo"
      description = "minio app secrets"
      data_json   = <<EOT
      {
        "accessKey": "this",
        "secretKey": "andThat" # pragma: allowlist secret
      }
      EOT
    }
  ]
  kv_policies = [
    {
      name         = "read-demo"
      capabilities = <<EOF
path "apps/data/demo" {
   capabilities = ["read"]
}
path "apps/metadata/demo" {
   capabilities = ["read"]
}
EOF
    }
  ]
  k8s_auths = [
    {
      name           = "dev"
      namespace      = "default"
      token_policies = ["read-demo"]
      token_ttl      = 3600
    }
  ]
}
