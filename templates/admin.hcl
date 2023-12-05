# MANAGE AUTH METHODS BROADLY ACROSS VAULT
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# CREATE, UPDATE, AND DELETE AUTH METHODS
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}

# LIST AUTH METHODS
path "sys/auth"
{
  capabilities = ["read"]
}

# LIST EXISTING POLICIES
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# CREATE AND MANAGE ACL POLICIES
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# LIST, CREATE, UPDATE, AND DELETE KEY/VALUE SECRETS
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# MANAGE SECRETS ENGINES
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}

# READ HEALTH CHECKS
path "sys/health"
{
  capabilities = ["read", "sudo"]
}

# MANAGE SECRETS ENGINES
path "*"
{
  capabilities = ["read", "list"]
}
