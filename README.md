# stuttgart-things/vault-base-setup

terraform module for base-setup configuration of hashicorp vault.

## EXAMPLE USAGE

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
        "secretKey": "andThat"
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
        "password": "helloGitHub",
        "policies": "default, admin"
      }
      EOT
  }
  ]
}

output "role_id" {
    value = module.vault-kvs.role_id
}

output "secret_id" {
    value = module.vault-kvs.secret_id
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
