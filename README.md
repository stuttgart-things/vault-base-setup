# stuttgart-things/vault-base-setup

terraform module for base-setup configuration of hashicorp vault.

## EXAMPLE USAGE

<details><summary><b>KUBECONFIG USAGE EXAMPLES</b></summary>

### Option 1: Using File Path (Existing Method)

```hcl
module "vault-base-setup" {
  source          = "github.com/stuttgart-things/vault-base-setup"
  vault_addr      = "https://vault.demo-infra.example.com"
  cluster_name    = "kind-dev2"
  context         = "kind-dev2"
  skip_tls_verify = true
  kubeconfig_path = "/home/sthings/.kube/kind-dev2"
  csi_enabled     = true
  namespace_csi   = "vault"
  vso_enabled     = true
  namespace_vso   = "vault"
  k8s_auths = [
    {
      name           = "dev"
      namespace      = "default"
      token_policies = ["read-k8s"]
      token_ttl      = 3600
    },
  ]
}
```

### Option 2: Using String Content (New Method)

```hcl
module "vault-base-setup" {
  source             = "github.com/stuttgart-things/vault-base-setup"
  vault_addr         = "https://vault.demo-infra.example.com"
  cluster_name       = "kind-dev2"
  context            = "kind-dev2"
  skip_tls_verify    = true
  kubeconfig_content = file("/home/sthings/.kube/kind-dev2")
  csi_enabled        = true
  namespace_csi      = "vault"
  vso_enabled        = true
  namespace_vso      = "vault"
  k8s_auths = [
    {
      name           = "dev"
      namespace      = "default"
      token_policies = ["read-k8s"]
      token_ttl      = 3600
    },
  ]
}
```

### Option 2b: Using an Environment Variable

```hcl
variable "kubeconfig_content_from_env" {
  type      = string
  sensitive = true
}

module "vault-base-setup" {
  source             = "github.com/stuttgart-things/vault-base-setup"
  vault_addr         = "https://vault.demo-infra.example.com"
  cluster_name       = "kind-dev2"
  context            = "kind-dev2"
  skip_tls_verify    = true
  kubeconfig_content = var.kubeconfig_content_from_env
  csi_enabled        = true
  namespace_csi      = "vault"
  vso_enabled        = true
  namespace_vso      = "vault"
  k8s_auths = [
    {
      name           = "dev"
      namespace      = "default"
      token_policies = ["read-k8s"]
      token_ttl      = 3600
    },
  ]
}
```

```bash
export TF_VAR_kubeconfig_content_from_env=$(cat /home/sthings/.kube/kind-dev2)
```

### Option 2c. Using a Heredoc (Inline String)

```hcl
module "vault-base-setup" {
  source             = "github.com/stuttgart-things/vault-base-setup"
  vault_addr         = "https://vault.demo-infra.example.com"
  cluster_name       = "kind-dev2"
  context            = "kind-dev2"
  skip_tls_verify    = true
  kubeconfig_content = <<-EOT
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: LS0tLS1CRUdJTi...
        server: https://127.0.0.1:6443
      name: kind-dev2
    contexts:
    - context:
        cluster: kind-dev2
        user: kind-dev2
      name: kind-dev2
    current-context: kind-dev2
    kind: Config
    preferences: {}
    users:
    - name: kind-dev2
      user:
        client-certificate-data: LS0tLS1CRUdJTi...
        client-key-data: LS0tLS1CRUdJTi...
  EOT
  csi_enabled        = true
  namespace_csi      = "vault"
  vso_enabled        = true
  namespace_vso      = "vault"
  k8s_auths = [
    {
      name           = "dev"
      namespace      = "default"
      token_policies = ["read-k8s"]
      token_ttl      = 3600
    },
  ]
}
```

Important Notes:
* Exactly one of kubeconfig_path or kubeconfig_content must be provided
* kubeconfig_content is marked as sensitive to prevent accidental exposure in logs
* Using file() function reads the file at plan time, while kubeconfig_path reads it during data source execution

</details>

<details><summary><b>EXECUTE VAULT CONFIG (VAULT SERVER)</b></summary>

### MODULE CALL

```bash
cat > vault-base.tf <<'EOF'
module "vault-secrets-setup" {
  source                   = "github.com/stuttgart-things/vault-base-setup"
  kubeconfig_path          = "/home/sthings/.kube/demo-infra"
  vault_addr               = "https://vault.demo-infra.sthings-vsphere.labul.sva.de"
  createDefaultAdminPolicy = true
  csi_enabled              = false
  vso_enabled              = false
  enableApproleAuth        = true
  skip_tls_verify          = true

  approle_roles = [
    {
      name           = "read-k8s"
      token_policies = ["read-k8s"]
    }
  ]

  secret_engines = [
    {
      path        = "apps"
      name        = "s3"
      description = "minio app secrets"
      data_json   = <<EOT
      {
        "accessKey": "this",
        "secretKey": "andThat"
      }
      EOT
    },
    {
      path        = "kubeconfigs"
      name        = "kind-dev2"
      description = "kubeconfig for kind-dev2 cluster"
      data_json   = jsonencode({
        kubeconfig = file("/home/sthings/.kube/kind-dev2")
      })
    }
  ]

  kv_policies = [
    {
      name         = "read-k8s"
      capabilities = <<CAPS
path "apps/s3" {
  capabilities = ["create", "read", "update", "patch", "list"]
}
path "kubeconfigs/data/*" {
  capabilities = ["read", "list"]
}
CAPS
    }
  ]
}

output "role_ids" {
  description = "Role IDs from the vault approle module"
  value       = module.vault-secrets-setup.role_id
}

output "secret_ids" {
  description = "Secret IDs from the vault approle module"
  value       = module.vault-secrets-setup.secret_id
  sensitive   = true
}
EOF
```

### EXECUTION

```bash
export VAULT_TOKEN=hvs.#..
terraform init
terraform apply --auto-approve
terraform output -json
```

### TEST APPROLE w/ ANSIBLE (OPTIONAL)

```bash
cat <<EOF > test-approle.yaml
---
- hosts: localhost
  become: true

  vars:
    vault_approle_id: "INSERT-HERE"
    vault_approle_secret: "INSERT-HERE" # pragma: allowlist secret
    vault_url: "https://vault.demo-infra.example.com"

    username: "{{ lookup('community.hashi_vault.hashi_vault', 'secret=apps/data/s3:accessKey validate_certs=false auth_method=approle role_id={{ vault_approle_id }} secret_id={{ vault_approle_secret }} url={{ vault_url }}') }}"
    kubeconfig: "{{ lookup('community.hashi_vault.hashi_vault', 'secret=kubeconfigs/data/kind-dev2:kubeconfig validate_certs=false auth_method=approle role_id={{ vault_approle_id }} secret_id={{ vault_approle_secret }} url={{ vault_url }}') }}" # pragma: allowlist secret

  tasks:
    - name: Debug
      debug:
        var: username
    - name: Debug
      debug:
        var: kubeconfig

EOF

ansible-playbook test-approle.yaml -vv
```

</details>

<details><summary><b>DEPLOY K8S AUTH ON CLUSTER</b></summary>

```hcl
cat > vault-k8s.tf <<'EOF'
module "vault-base-setup" {
  source          = "github.com/stuttgart-things/vault-base-setup"
  vault_addr      = "https://vault.demo-infra.example.com"
  cluster_name    = "kind-dev2"
  context         = "kind-dev2"
  skip_tls_verify = true
  kubeconfig_path = "/home/sthings/.kube/kind-dev2"
  csi_enabled     = true
  namespace_csi   = "vault"
  vso_enabled     = true
  namespace_vso   = "vault"
  k8s_auths = [
    {
      name           = "dev"
      namespace      = "default"
      token_policies = ["read-k8s"]
      token_ttl      = 3600
    },
  ]
}
EOF
```

```bash
# ONLY APPLY IF VSO IS ENABLED
kubectl apply -f https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/chart/crds/secrets.hashicorp.com_vaultconnections.yaml
kubectl apply -f https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/chart/crds/secrets.hashicorp.com_vaultauths.yaml

export VAULT_TOKEN=<TOKEN>
terraform init --upgrade
terraform apply
```

```yaml
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: demo-infra
  namespace: default
spec:
  vaultAuthRef: dev            # Reference to a VaultAuth CRD, e.g., token or approle
  mount: kubeconfigs                  # The KV mount path in Vault
  type: kv-v2                  # KV engine version
  path: demo-infra             # Path under the mount
  refreshAfter: 10s            # How often to sync from Vault
  destination:
    create: true
    name: demo-infra-kube # Name of the Kubernetes Secret to create
```

</details>

<details><summary><b>DEPLOY VAULT SERVER WITH CSI PROVIDER</b></summary>

```hcl
module "vault-base-setup" {
  source                 = "github.com/stuttgart-things/vault-base-setup"
  vault_addr             = "https://vault.demo-infra.example.com"
  cluster_name           = "kind-dev2"
  context                = "kind-dev2"
  skip_tls_verify        = true
  kubeconfig_path        = "/home/sthings/.kube/kind-dev2"
  vault_enabled          = true
  vault_dev_mode         = true
  vault_injector_enabled = false
  vault_csi_enabled      = true
  namespace_vault        = "vault"
  csi_enabled            = false
  vso_enabled            = false
}
```

</details>

<details><summary><b>CSI PROVIDER EXAMPLE APPLICATION</b></summary>

### SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-lab-creds
  namespace: default
spec:
  provider: vault
  parameters:
    objects: |
      - objectName: "lab"
        secretPath: "env/data/labul"
        secretKey: "lab"
    roleName: dev
    vaultAddress: https://vault.dev11.4sthings.tiab.ssc.sva.de
    vaultKubernetesMountPath: utah-dev
    vaultSkipTLSVerify: "true"
```

### Example Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app3
  labels:
    app: demo
spec:
  selector:
    matchLabels:
      app: demo
  replicas: 1
  template:
    metadata:
      labels:
        app: demo
    spec:
      serviceAccountName: dev
      containers:
        - name: app
          image: nginx
          volumeMounts:
            - name: 'vault-user-creds'
              mountPath: '/mnt/secrets-store'
              readOnly: true
      volumes:
        - name: vault-user-creds
          csi:
            driver: 'secrets-store.csi.k8s.io'
            readOnly: true
            volumeAttributes:
              secretProviderClass: 'vault-lab-creds'
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
