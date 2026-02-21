// MOUNT PKI SECRETS ENGINE
resource "vault_mount" "pki" {
  count                     = var.pki_enabled ? 1 : 0
  path                      = var.pki_path
  type                      = "pki"
  description               = "PKI secrets engine for ${var.pki_common_name}"
  default_lease_ttl_seconds = var.pki_default_ttl_seconds
  max_lease_ttl_seconds     = var.pki_max_ttl_seconds
}

// GENERATE ROOT CA
resource "vault_pki_secret_backend_root_cert" "root" {
  count                = var.pki_enabled ? 1 : 0
  backend              = vault_mount.pki[0].path
  type                 = var.pki_type
  common_name          = var.pki_common_name
  ttl                  = var.pki_root_ttl
  key_type             = var.pki_key_type
  key_bits             = var.pki_key_bits
  exclude_cn_from_sans = true
  organization         = var.pki_organization
  country              = var.pki_country
}

// CONFIGURE PKI URLS
resource "vault_pki_secret_backend_config_urls" "urls" {
  count                   = var.pki_enabled ? 1 : 0
  backend                 = vault_mount.pki[0].path
  issuing_certificates    = ["${var.vault_addr}/v1/${var.pki_path}/ca"]
  crl_distribution_points = ["${var.vault_addr}/v1/${var.pki_path}/crl"]

  depends_on = [vault_pki_secret_backend_root_cert.root]
}

// CREATE PKI ROLES
resource "vault_pki_secret_backend_role" "roles" {
  for_each = {
    for role in var.pki_roles :
    role.name => role
    if var.pki_enabled
  }

  backend            = vault_mount.pki[0].path
  name               = each.value["name"]
  ttl                = lookup(each.value, "ttl", null)
  max_ttl            = each.value["max_ttl"]
  allowed_domains    = each.value["allowed_domains"]
  allow_subdomains   = each.value["allow_subdomains"]
  allow_bare_domains = lookup(each.value, "allow_bare_domains", false)
  key_type           = lookup(each.value, "key_type", var.pki_key_type)
  key_bits           = lookup(each.value, "key_bits", var.pki_key_bits)
  generate_lease     = true

  depends_on = [vault_pki_secret_backend_config_urls.urls]
}

// CREATE PKI POLICY
resource "vault_policy" "pki" {
  count = var.pki_enabled ? 1 : 0

  name   = var.pki_policy_name
  policy = <<-EOT
path "${var.pki_path}/issue/*" {
  capabilities = ["create", "update"]
}

path "${var.pki_path}/sign/*" {
  capabilities = ["create", "update"]
}

path "${var.pki_path}/certs" {
  capabilities = ["list"]
}

path "${var.pki_path}/cert/*" {
  capabilities = ["read"]
}

path "${var.pki_path}/ca" {
  capabilities = ["read"]
}

path "${var.pki_path}/ca_chain" {
  capabilities = ["read"]
}

path "${var.pki_path}/crl" {
  capabilities = ["read"]
}

path "${var.pki_path}/roles/*" {
  capabilities = ["read"]
}
  EOT
}
