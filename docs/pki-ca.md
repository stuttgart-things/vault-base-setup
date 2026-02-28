# PKI CA with cert-manager

This guide covers setting up Vault as a PKI Certificate Authority and integrating it with cert-manager for automated certificate issuance across Kubernetes clusters.

## Architecture

```text
+-------------------+         +-------------------+         +-------------------+
|  Terraform        |         |  Vault (Cluster A)|         | cert-manager      |
|  vault-base-setup | ------> |  PKI Engine       | <------ | (Cluster B)       |
|                   |         |  Root CA          |         | ClusterIssuer     |
|  pki_enabled=true |         |  Roles + Policy   |         | Certificate       |
+-------------------+         +-------------------+         +-------------------+
```

The PKI engine runs on the Vault instance. cert-manager can run on the same or a different cluster and connects to Vault via its ingress URL.

## Step 1: Deploy PKI Engine with Terraform

```hcl
module "vault-base-setup" {
  source          = "github.com/stuttgart-things/vault-base-setup"
  vault_addr      = "https://vault.demo-infra.sthings-vsphere.labul.sva.de"
  skip_tls_verify = true
  kubeconfig_path = "/home/sthings/.kube/demo-infra"
  cluster_name    = "demo-infra"

  csi_enabled = false
  vso_enabled = false

  # PKI CA configuration
  pki_enabled      = true
  pki_path         = "pki"
  pki_common_name  = "sthings-vsphere.labul.sva.de"
  pki_organization = "sva"
  pki_country      = "DE"
  pki_key_type     = "rsa"
  pki_key_bits     = 2048
  pki_root_ttl     = "87600h"

  pki_roles = [
    {
      name             = "sthings-vsphere"
      allowed_domains  = ["sthings-vsphere.labul.sva.de"]
      allow_subdomains = true
      max_ttl          = "720h"
    }
  ]
}
```

Apply the configuration:

```bash
export VAULT_TOKEN=hvs.<root-token>
terraform init
terraform apply
```

### What Gets Created

| Resource | Path / Name | Purpose |
|----------|-------------|---------|
| PKI Mount | `pki/` | PKI secrets engine |
| Root CA | `pki/issuer/...` | Self-signed root certificate |
| URL Config | `pki/config/urls` | CA and CRL distribution endpoints |
| Role | `pki/roles/sthings-vsphere` | Certificate issuance role with domain constraints |
| Policy | `pki-issue` | ACL policy granting issue/sign/read capabilities |

### PKI Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `pki_enabled` | bool | `false` | Enable PKI secrets engine |
| `pki_path` | string | `"pki"` | Mount path |
| `pki_common_name` | string | `"example.com"` | Root CA common name |
| `pki_organization` | string | `""` | Root CA organization |
| `pki_country` | string | `""` | Root CA country |
| `pki_type` | string | `"internal"` | Root cert type (`internal` or `exported`) |
| `pki_key_type` | string | `"rsa"` | Key algorithm (`rsa` or `ec`) |
| `pki_key_bits` | number | `2048` | Key size (2048/4096 for RSA, 256/384 for EC) |
| `pki_root_ttl` | string | `"87600h"` | Root CA lifetime (default 10 years) |
| `pki_default_ttl_seconds` | number | `3600` | Default lease TTL |
| `pki_max_ttl_seconds` | number | `315360000` | Max lease TTL |
| `pki_policy_name` | string | `"pki-issue"` | Name of the ACL policy |
| `pki_roles` | list(object) | `[]` | Certificate issuance roles |

### Outputs

| Output | Description |
|--------|-------------|
| `pki_ca_cert` | Root CA certificate in PEM format |
| `pki_path` | PKI engine mount path |
| `pki_roles` | List of created role names |

## Step 2: Verify PKI Engine

After applying, verify the PKI engine is working by issuing a test certificate via the Vault API:

```bash
curl -sk \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request POST \
  --data '{"common_name": "test.sthings-vsphere.labul.sva.de", "ttl": "24h"}' \
  $VAULT_ADDR/v1/pki/issue/sthings-vsphere
```

## Step 3: Create a Vault Token for cert-manager

Create a token scoped to the `pki-issue` policy:

```bash
curl -sk \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request POST \
  --data '{"policies": ["pki-issue"], "ttl": "720h"}' \
  $VAULT_ADDR/v1/auth/token/create
```

Store the token as a Kubernetes secret in the cert-manager namespace on the target cluster:

```bash
kubectl create secret generic vault-pki-token \
  --namespace cert-manager \
  --from-literal=token="hvs.<pki-token>"
```

## Step 4: Retrieve the Vault Ingress CA Certificate

When Vault is exposed via an ingress with a TLS certificate signed by a private CA (which is common in on-prem environments), cert-manager must trust that CA to establish a connection. Without it, the ClusterIssuer will fail with:

```text
Failed to verify Vault is initialized and unsealed:
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

### Retrieve the CA certificate

**Option A** - Extract from the TLS secret on the Vault cluster:

```bash
kubectl get secret <vault-ingress-tls-secret> \
  -n vault \
  -o jsonpath='{.data.ca\.crt}'
```

This outputs the base64-encoded CA certificate directly, ready for the `caBundle` field.

**Option B** - Extract from the live TLS connection (requires the full chain):

```bash
# Get the issuer CA, not the leaf certificate
openssl s_client -connect vault.example.com:443 \
  -servername vault.example.com -showcerts 2>/dev/null \
  | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' \
  | base64 -w0
```

**Important:** The `caBundle` field requires the **issuing CA certificate** (the certificate that signed the ingress TLS cert), not the leaf/server certificate itself. Using the leaf certificate will result in:

```text
cert bundle didn't contain any valid certificates
```

## Step 5: Create the ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-pki
spec:
  vault:
    path: pki/sign/sthings-vsphere
    server: https://vault.demo-infra.sthings-vsphere.labul.sva.de
    caBundle: <base64-encoded-ca-certificate>
    auth:
      tokenSecretRef:
        name: vault-pki-token
        key: token
```

The `caBundle` contains the base64-encoded PEM of the CA that signed the Vault ingress TLS certificate. The token secret must exist in the cert-manager controller's `--cluster-resource-namespace` (defaults to the cert-manager pod's namespace).

Verify the issuer is ready:

```bash
kubectl get clusterissuer vault-pki
# NAME        READY   AGE
# vault-pki   True    9s
```

## Step 6: Request a Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: default
spec:
  secretName: my-app-tls
  issuerRef:
    name: vault-pki
    kind: ClusterIssuer
  commonName: myapp.sthings-vsphere.labul.sva.de
  dnsNames:
    - myapp.sthings-vsphere.labul.sva.de
  duration: 720h
  renewBefore: 24h
```

Verify the certificate was issued:

```bash
kubectl get certificate my-app-tls
# NAME         READY   SECRET       AGE
# my-app-tls   True    my-app-tls   10s
```

Inspect the issued certificate:

```bash
kubectl get secret my-app-tls -o jsonpath='{.data.tls\.crt}' \
  | base64 -d \
  | openssl x509 -noout -subject -issuer -dates
# subject=CN=myapp.sthings-vsphere.labul.sva.de
# issuer=C=DE, O=sva, CN=sthings-vsphere.labul.sva.de
# notBefore=...
# notAfter=...
```

## Cross-Cluster: Issuing Certificates from a Remote Vault

When the PKI engine already exists on a central Vault instance, edge clusters can create a Vault-backed ClusterIssuer without recreating the PKI engine locally. Set `pki_enabled = false` and provide the policy name and CA bundle explicitly.

### Module Call (Edge Cluster)

```hcl
module "vault-base-setup" {
  source          = "github.com/stuttgart-things/vault-base-setup"
  vault_addr      = "https://vault.k3s-infra.sthings-vsphere.labul.sva.de"
  skip_tls_verify = true
  kubeconfig_path = "/path/to/edge-kubeconfig"
  cluster_name    = "edge-cluster"

  csi_enabled = false
  vso_enabled = false
  pki_enabled = false

  certmanager_vault_issuer_enabled     = true
  certmanager_vault_issuer_pki_role    = "k3s-infra"
  certmanager_vault_issuer_server      = "https://vault.k3s-infra.sthings-vsphere.labul.sva.de"
  certmanager_vault_issuer_ca_bundle   = var.vault_ca_bundle
  certmanager_vault_issuer_policy_name = "pki-issue"
}
```

### What This Creates

| Resource | Description |
|----------|-------------|
| `vault_token.certmanager` | Token scoped to the existing `pki-issue` policy on the remote Vault |
| `kubernetes_secret_v1.certmanager_vault_token` | K8s secret in the cert-manager namespace on the edge cluster |
| `kubectl_manifest.vault_clusterissuer` | ClusterIssuer pointing to the remote Vault with `caBundle` |

### Retrieving the CA Bundle

The `vault_ca_bundle` must contain the base64-encoded PEM of the CA that signed the remote Vault's ingress TLS certificate. See [Step 4: Retrieve the Vault Ingress CA Certificate](#step-4-retrieve-the-vault-ingress-ca-certificate) above.

### Verify

```bash
kubectl get clusterissuer vault-pki
# NAME        READY   AGE
# vault-pki   True    10s
```

## Troubleshooting

### ClusterIssuer shows `VaultError` with TLS failure

```text
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

The `caBundle` is missing or does not contain the correct CA. See [Step 4](#step-4-retrieve-the-vault-ingress-ca-certificate).

### ClusterIssuer shows `crypto/rsa: verification error`

```text
tls: failed to verify certificate: x509: certificate signed by unknown authority
(possibly because of "crypto/rsa: verification error" while trying to verify
candidate authority certificate "...")
```

The `caBundle` contains a **corrupted** CA certificate. The base64 string may have been mangled during copy-paste — even a single character difference will cause this. The corrupted cert can still parse and self-verify, making this hard to spot.

**To diagnose**, verify the caBundle CA against the actual leaf certificate served by Vault:

```bash
# Extract caBundle from ClusterIssuer
kubectl get clusterissuer vault-pki -o jsonpath='{.spec.vault.caBundle}' \
  | base64 -d > /tmp/issuer-ca.pem

# Get leaf cert from Vault ingress
echo | openssl s_client -connect vault.example.com:443 \
  -servername vault.example.com 2>/dev/null \
  | openssl x509 > /tmp/leaf.pem

# Verify — must print "OK"
openssl verify -CAfile /tmp/issuer-ca.pem /tmp/leaf.pem
```

If verification fails with `certificate signature failure` or `RSA_padding_check` errors, regenerate the caBundle from the correct CA:

```bash
# From Vault PKI API
curl -sk --header "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/pki/ca/pem | base64 -w0
```

### ClusterIssuer rejected with "cert bundle didn't contain any valid certificates"

You are providing the leaf/server certificate instead of the issuing CA certificate. Extract the CA cert from the Vault cluster's TLS secret (`ca.crt` key) rather than from the live TLS connection's first certificate.

### Certificate stays in `Pending` state

Check the CertificateRequest and Order status:

```bash
kubectl describe certificaterequest -n <namespace>
```

Common causes:

- The Vault token has expired - create a new one and update the secret
- The PKI role does not allow the requested domain - check `allowed_domains` and `allow_subdomains`
- The requested TTL exceeds the role's `max_ttl`
