# stuttgart-things/vault-base-setup

terraform module for base-setup configuration of hashicorp vault.

## EXAMPLE USAGE

<details><summary><b>SECRETS + K8S AUTH</b></summary>

```hcl
module "vault-secrets-setup" {
  source = "../../vault-base-setup/"
  kubeconfig_path = "/home/sthings/.kube/demo"
  vault_addr = "https://vault.demo.sthings-vsphere.labul.sva.de"
  createDefaultAdminPolicy = true
  csi_enabled = false
  vso_enabled = false
  cluster_name = "demo"
  enableApproleAuth = false
  secret_engines = [
    {
      path         = "apps"
      name         = "demo"
      description  = "minio app secrets"
      data_json    = <<EOT
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
      name = "dev"
      namespace = "default"
      token_policies = ["read-demo"]
      token_ttl = 3600
    }
  ]
}
```

```bash
export VAULT_TOKEN=<TOKEN>
terraform init --upgrade
terraform apply
```

```yaml
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vault-static-apps1
  namespace: default
spec:
  vaultAuthRef: dev
  mount: apps
  type: kv-v2
  path: demo
  refreshAfter: 10s
  destination:
    create: true
    name: vso-app
```


</details>

<details><summary><b>DEPLOY K8S AUTH ON CLUSTER</b></summary>

```hcl
module "vault-base-setup" {
  source = "github.com/stuttgart-things/vault-base-setup"
  vault_addr = "https://vault.dev11.4sthings.tiab.ssc.sva.de"
  cluster_name = "labul-app1"
  kubeconfig_path = "/home/sthings/.kube/labul-app1"
  csi_enabled = true
  namespace_csi = "vault"
  vso_enabled = true
  namespace_vso = "vault"
  k8s_auths = [
    {
	name = "dev"
	namespace = "default"
	token_policies = ["read-all-s3-kvv2", "read-write-all-s3-kvv2"]
	token_ttl = 3600
    },
  ]
}
```

```bash
# ONLY APPLY IF VSO IS ENABLED
kubectl apply -f https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/chart/crds/secrets.hashicorp.com_vaultconnections.yaml
kubectl apply -f https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/chart/crds/secrets.hashicorp.com_vaultauths.yaml

export VAULT_TOKEN=<TOKEN>
terraform init --upgrade
terraform apply
```

</details>


<details><summary>CALL MODULE W/ VALUES</summary>

```hcl
module "vault-base-setup" {
  source = "github.com/stuttgart-things/vault-base-setup"
  createDefaultAdminPolicy = true
  secret_engines = [
    {
      path         = "cloud"
      name         = "vsphere"
      description  = "vsphere secrets",
      data_json    = <<EOT
      {
        "ip": "10.31.101.51"
      }
      EOT
    },
    {
      path         = "apps"
      name         = "s3"
      description  = "minio s3 secrets"
      data_json    = <<EOT
      {
        "accessKey": "this",
        "secretKey": "andThat" # pragma: allowlist secret
      }
      EOT
    }
  ]
  kv_policies = [
    {
      name         = "read-all-s3-kvv2"
      capabilities = <<EOF
path "s3-*/*" {
    capabilities = ["list", "read"]
}
EOF
    },
    {
      name         = "read-write-all-s3-kvv2"
      capabilities = <<EOF
path "s3-*/*" {
    capabilities = ["create", "read", "update", "patch", "list"]
}
EOF
    }
  ]
  enableApproleAuth = true
  approle_roles = [
    {
      name         = "s3"
      token_policies = ["read-all-s3-kvv2", "read-write-all-s3-kvv2"]
    },
    {
      name         = "s4"
      token_policies = ["read-all-s3-kvv2"]
    }
  ]
  enableUserPass = true
  user_list = [
    {
      path         = "auth/userpass/users/user1"
      data_json    = <<EOT
      {
        "password": "helloGitHub", # pragma: allowlist secret
        "policies": ""read-all-s3-kvv2", "read-write-all-s3-kvv2", "admin"
      }
      EOT
  }
  ]
  kubeconfig_path = "/home/sthings/.kube/labda-app"
  k8s_auths = [
    {
      name = "dev"
      namespace = "default"
      token_policies = ["read-all-s3-kvv2", "read-write-all-s3-kvv2"]
      token_ttl = 3600
    },
    {
      name = "cicd"
      namespace = "tektoncd"
      token_policies = ["read-all-tektoncd-kvv2"]
      token_ttl = 3600
    }
  ]
}

output "role_id" {
    value = module.vault-base-setup.role_id
}

output "secret_id" {
    value = module.vault-base-setup.secret_id
}
```

</details>

<details><summary>EXECUTE TERRAFORM</summary>

```bash
export VAULT_ADDR=${VAULT_ADDR}
export VAULT_TOKEN=${VAULT_TOKEN}

terraform init
terraform validate
terraform plan
terraform apply
```

</details>

## Author Information

```bash
Xiaomin Lai, stuttgart-things 10/2023
Patrick Hermann, stuttgart-things 12/2023
```

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.
