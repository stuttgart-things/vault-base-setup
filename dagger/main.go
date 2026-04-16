// Dagger module for testing vault-base-setup against an ephemeral Vault.
//
// Two test entry points are exposed:
//
//   - TestTerraformApplyDev runs `terraform apply` against a Vault container
//     started in dev mode (auto-unsealed, plain HTTP, fixed root token).
//
//   - TestTerraformApplyTls runs `terraform apply` against a Vault container
//     configured with a self-signed TLS cert and file storage, initialised
//     and unsealed from a helper container, then exercised over HTTPS with
//     VAULT_CACERT wired up for proper CA verification.
//
// The test fixture lives at dagger/tests/fixture.tf and exercises the
// Vault-native features of the root module (AppRole, UserPass, KV, PKI,
// policies). Kubernetes / Helm / cert-manager / VSO / CSI features are
// disabled because no live cluster is available inside the Dagger runtime.
package main

import (
	"context"
	"fmt"
	"strings"

	"dagger/vault-base-setup/internal/dagger"
)

const (
	defaultTerraformImage = "hashicorp/terraform:1.14"
	defaultVaultImage     = "hashicorp/vault:1.21"
	defaultAlpineImage    = "alpine:3.23"
	devRootToken          = "dagger-root-token"
	vaultHostname         = "vault"
	vaultPort             = 8200
)

type VaultBaseSetup struct {
	// Source is the root of the terraform module being tested (the repo root,
	// i.e. the directory containing vault.tf, auth.tf, pki.tf, etc.).
	// +private
	Source *dagger.Directory
}

// New constructs the module. Pass the repository root as `source`, for
// example: `dagger call -m ./dagger --source=. test-terraform-apply-dev`.
func New(
	// Repository root containing the terraform module under test.
	// +defaultPath=".."
	// +ignore=[".dagger", "**/.terraform", "**/terraform.tfstate*"]
	source *dagger.Directory,
) *VaultBaseSetup {
	return &VaultBaseSetup{Source: source}
}

// VaultDevService returns a Vault container running in dev mode as a Dagger
// service. The server is auto-initialised, auto-unsealed, uses in-memory
// storage and listens on plain HTTP at :8200 with a fixed root token.
func (m *VaultBaseSetup) VaultDevService(
	// +optional
	// +default="hashicorp/vault:1.21"
	image string,
	// +optional
	// +default="dagger-root-token"
	rootToken string,
) *dagger.Service {
	if image == "" {
		image = defaultVaultImage
	}
	if rootToken == "" {
		rootToken = devRootToken
	}

	return dag.Container().
		From(image).
		WithExposedPort(vaultPort).
		AsService(dagger.ContainerAsServiceOpts{
			Args: []string{
				"vault", "server", "-dev",
				fmt.Sprintf("-dev-listen-address=0.0.0.0:%d", vaultPort),
				"-dev-root-token-id=" + rootToken,
			},
		})
}

// TestTerraformApplyDev runs `terraform init` + `terraform apply` against a
// Vault dev-mode service. Returns the terraform output on success.
func (m *VaultBaseSetup) TestTerraformApplyDev(
	ctx context.Context,
	// +optional
	// +default="hashicorp/terraform:1.14"
	terraformImage string,
	// +optional
	// +default="hashicorp/vault:1.21"
	vaultImage string,
) (string, error) {
	if terraformImage == "" {
		terraformImage = defaultTerraformImage
	}
	if vaultImage == "" {
		vaultImage = defaultVaultImage
	}

	vault := m.VaultDevService(vaultImage, devRootToken)
	vaultAddr := fmt.Sprintf("http://%s:%d", vaultHostname, vaultPort)

	out, err := m.terraformContainer(terraformImage).
		WithServiceBinding(vaultHostname, vault).
		WithEnvVariable("VAULT_TOKEN", devRootToken).
		WithEnvVariable("VAULT_ADDR", vaultAddr).
		WithExec([]string{"terraform", "init", "-input=false", "-no-color"}).
		WithExec([]string{
			"terraform", "apply", "-auto-approve", "-input=false", "-no-color",
			"-var=vault_addr=" + vaultAddr,
			"-var=skip_tls_verify=true",
		}).
		WithExec([]string{"terraform", "output", "-no-color"}).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("terraform apply (dev) failed: %w", err)
	}
	return fmt.Sprintf("test terraform-apply-dev: OK\n%s", out), nil
}

// TestTerraformApplyTls runs `terraform init` + `terraform apply` against a
// Vault server that listens over HTTPS with a self-signed cert and has been
// initialised + unsealed by a helper container. The terraform client verifies
// the Vault CA via VAULT_CACERT.
func (m *VaultBaseSetup) TestTerraformApplyTls(
	ctx context.Context,
	// +optional
	// +default="hashicorp/terraform:1.14"
	terraformImage string,
	// +optional
	// +default="hashicorp/vault:1.21"
	vaultImage string,
) (string, error) {
	if terraformImage == "" {
		terraformImage = defaultTerraformImage
	}
	if vaultImage == "" {
		vaultImage = defaultVaultImage
	}

	certs := m.generateTlsCerts(vaultHostname)
	vault := m.vaultTlsService(vaultImage, certs)
	vaultAddr := fmt.Sprintf("https://%s:%d", vaultHostname, vaultPort)

	rootToken, err := m.initAndUnsealVault(ctx, vaultImage, vault, certs, vaultAddr)
	if err != nil {
		return "", err
	}

	out, err := m.terraformContainer(terraformImage).
		WithServiceBinding(vaultHostname, vault).
		WithMountedDirectory("/vault-ca", certs).
		WithEnvVariable("VAULT_TOKEN", rootToken).
		WithEnvVariable("VAULT_ADDR", vaultAddr).
		WithEnvVariable("VAULT_CACERT", "/vault-ca/ca.pem").
		WithExec([]string{"terraform", "init", "-input=false", "-no-color"}).
		WithExec([]string{
			"terraform", "apply", "-auto-approve", "-input=false", "-no-color",
			"-var=vault_addr=" + vaultAddr,
			"-var=skip_tls_verify=false",
		}).
		WithExec([]string{"terraform", "output", "-no-color"}).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("terraform apply (tls) failed: %w", err)
	}
	return fmt.Sprintf("test terraform-apply-tls: OK\n%s", out), nil
}

// terraformContainer mounts the repo at /src and chdirs into the test
// fixture. The fixture references the parent module via `source = "../../"`.
func (m *VaultBaseSetup) terraformContainer(image string) *dagger.Container {
	return dag.Container().
		From(image).
		WithMountedDirectory("/src", m.Source).
		WithWorkdir("/src/dagger/tests")
}

// generateTlsCerts produces a self-signed CA and server cert/key via openssl.
// Returned directory contains: ca.pem, ca.key, server.pem, server.key.
func (m *VaultBaseSetup) generateTlsCerts(hostname string) *dagger.Directory {
	script := fmt.Sprintf(`set -eu
cd /out
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 3650 -key ca.key -out ca.pem \
  -subj "/CN=dagger-vault-ca"
openssl genrsa -out server.key 2048
cat > csr.conf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext
[dn]
CN = %s
[req_ext]
subjectAltName = @alt_names
[alt_names]
DNS.1 = %s
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF
openssl req -new -key server.key -out server.csr -config csr.conf
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out server.pem -days 365 -extfile csr.conf -extensions req_ext
rm -f server.csr csr.conf ca.srl
`, hostname, hostname)

	return dag.Container().
		From(defaultAlpineImage).
		WithExec([]string{"apk", "add", "--no-cache", "openssl"}).
		WithWorkdir("/out").
		WithExec([]string{"sh", "-c", script}).
		Directory("/out")
}

// vaultTlsService returns a Vault container running in server mode with TLS
// and file storage, listening on :8200. The returned service is sealed on
// startup and must be initialised + unsealed before use.
func (m *VaultBaseSetup) vaultTlsService(image string, certs *dagger.Directory) *dagger.Service {
	config := `
ui            = true
disable_mlock = true

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/server.pem"
  tls_key_file  = "/vault/tls/server.key"
}

api_addr     = "https://vault:8200"
cluster_addr = "https://vault:8201"
`

	// The hashicorp/vault image runs as the unprivileged `vault` user, so we
	// copy the TLS material in as root, create the storage dir, then chown
	// everything before the service starts.
	return dag.Container().
		From(image).
		WithUser("root").
		WithDirectory("/vault/tls", certs).
		WithNewFile("/vault/config/config.hcl", config).
		WithExec([]string{"sh", "-c",
			"mkdir -p /vault/data && chown -R vault:vault /vault/data /vault/tls /vault/config"}).
		WithUser("vault").
		WithExposedPort(vaultPort).
		AsService(dagger.ContainerAsServiceOpts{
			Args: []string{"vault", "server", "-config=/vault/config/config.hcl"},
		})
}

// initAndUnsealVault runs `vault operator init` + `vault operator unseal`
// against the TLS-enabled service and returns the root token on stdout.
func (m *VaultBaseSetup) initAndUnsealVault(
	ctx context.Context,
	image string,
	vault *dagger.Service,
	certs *dagger.Directory,
	vaultAddr string,
) (string, error) {
	// Wait for Vault API to respond: exit 0 = unsealed, 2 = sealed, 1 = error.
	// Then init with a single unseal key, unseal, and print only the root token.
	script := `set -eu
ready=0
for i in $(seq 1 60); do
  set +e
  vault status >/dev/null 2>&1
  code=$?
  set -e
  case $code in
    0|2) ready=1; break ;;
  esac
  sleep 1
done
[ "$ready" -eq 1 ] || { echo "vault did not become reachable" >&2; exit 1; }
vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/init.json
UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' /tmp/init.json)
vault operator unseal "$UNSEAL_KEY" >/dev/null
jq -r '.root_token' /tmp/init.json
`

	rawToken, err := dag.Container().
		From(image).
		WithUser("root").
		WithExec([]string{"apk", "add", "--no-cache", "jq"}).
		WithServiceBinding(vaultHostname, vault).
		WithMountedDirectory("/vault-ca", certs).
		WithEnvVariable("VAULT_ADDR", vaultAddr).
		WithEnvVariable("VAULT_CACERT", "/vault-ca/ca.pem").
		WithExec([]string{"sh", "-c", script}).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("vault init/unseal failed: %w", err)
	}

	token := strings.TrimSpace(rawToken)
	if token == "" {
		return "", fmt.Errorf("vault init returned empty root token")
	}
	return token, nil
}
