# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**vault-base-setup** is a Terraform root module for configuring HashiCorp Vault on Kubernetes clusters. It supports Vault server deployment (Bitnami Helm chart), multiple auth methods (Kubernetes, AppRole, UserPass), secret engines (KV v2, PKI), and integrations (cert-manager, CSI Driver, Vault Secrets Operator).

## Common Commands

```bash
# Format
terraform fmt -recursive

# Validate
terraform validate
tflint                        # Uses .tflint.hcl (recommended preset)

# Run pre-commit hooks
pre-commit run -a

# Run integration tests (requires live Vault + K8s cluster)
cd tests/ && terraform init && terraform plan && terraform apply

# Task runner (requires 'task' CLI)
task terraform:fmt             # Format all TF files
task check                     # Run pre-commit hooks
task commit                    # Format, lint, commit, push
task pr                        # Full PR workflow (commit + create + merge)
```

**Environment:** Vault provider authenticates via `VAULT_TOKEN` env var. Kubernetes access requires either `kubeconfig_path` or `kubeconfig_content` variable.

## Architecture

This is a **single root module** (no submodules). All resources are in the root directory, logically grouped by file. Each feature is independently toggleable via boolean variables.

### File Organization

| File | Feature | Toggle Variable |
|------|---------|-----------------|
| `vault.tf` | Vault server Helm deployment + auto-unseal + Gateway API | `vault_enabled` |
| `auth.tf` | AppRole and UserPass auth backends | `enableApproleAuth`, `enableUserPass` |
| `k8s.tf` | Kubernetes auth backends, service accounts, RBAC | via `k8s_auths` list |
| `pki.tf` | PKI secret engine, root CA, roles | `pki_enabled` |
| `cert-manager.tf` | cert-manager Helm + bootstrap CA + Vault ClusterIssuer | `certmanager_enabled`, `certmanager_vault_issuer_enabled` |
| `kv-mounts.tf` | KV v2 secret engine mounts and data | via `secret_engines` list |
| `policy-template.tf` | Vault policies (KV access + admin) | via `kv_policies` list |
| `csi.tf` | Secrets Store CSI Driver Helm | `csi_enabled` |
| `vso.tf` | Vault Secrets Operator Helm + CRDs | `vso_enabled` |
| `provider.tf` | Provider configs (kubernetes, kubectl, helm, vault, local, null) | — |
| `variables.tf` | All input variables (150+) | — |
| `outputs.tf` | Role IDs, secret IDs, PKI certs, issuer names | — |

### Key Patterns

- **Conditional creation:** `count = var.feature_enabled ? 1 : 0` for feature toggling
- **Multi-instance resources:** `for_each` on `k8s_auths`, `pki_roles`, `secret_engines`
- **Kubeconfig flexibility:** Three input methods — file path (`kubeconfig_path`), string content (`kubeconfig_content`), or parsed from environment
- **Template files:** `templates/` contains Vault CRD templates (`vault-auth.tpl`, `vault-connection.tpl`) and policy HCL (`admin.hcl`)
- **Validation:** `null_resource` with preconditions for input validation (e.g., Vault ingress hostname requirement)
- **Dependency ordering:** Explicit `depends_on` between Helm releases and K8s manifests

### Tests

Integration tests live in `tests/` and reference the parent module via `source = "../"`. They require a live Vault and Kubernetes cluster. CI runs them via GitHub Actions after validation passes.

## CI/CD

GitHub Actions workflow (`.github/workflows/terraform.yaml`) runs on feature/fix/renovate branches and PRs:
1. **Validate** — `terraform validate` + `tflint` (Terraform >= 1.10.5)
2. **Docs** — Auto-generate terraform-docs
3. **Security** — Scan for HIGH/CRITICAL severity issues
4. **Test** — Integration tests (depends on validate)

Uses reusable workflows from `stuttgart-things/github-workflow-templates`. Runner: `ghr-vault-base-setup-in-cluster` (self-hosted, in-cluster).

## Required Providers

Terraform >= 1.10.5. Providers: `hashicorp/kubernetes` (>= 2.24.0), `gavinbunney/kubectl` (>= 1.14.0), `hashicorp/vault` (>= 3.21.0), `hashicorp/helm` (>= 2.12.1), `hashicorp/local` (2.7.0), `hashicorp/null` (>= 3.2.0).
