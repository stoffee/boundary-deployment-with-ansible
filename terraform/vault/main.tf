resource "vault_mount" "transit" {
  path        = var.transit_mount_path
  type        = "transit"
  description = "Transit secrets engine for Boundary encryption 🔑"
}

resource "vault_transit_secret_backend_key" "boundary_root" {
  backend = vault_mount.transit.path
  name    = "${var.key_prefix}-root"
  type    = "aes256-gcm96"
}

resource "vault_transit_secret_backend_key" "boundary_worker_auth" {
  backend = vault_mount.transit.path
  name    = "${var.key_prefix}-worker-auth"
  type    = "aes256-gcm96"
}

resource "vault_transit_secret_backend_key" "boundary_recovery" {
  count   = var.enable_recovery_key ? 1 : 0
  backend = vault_mount.transit.path
  name    = "${var.key_prefix}-recovery"
  type    = "aes256-gcm96"
}

resource "vault_transit_secret_backend_key" "boundary_worker_auth_storage" {
  backend = vault_mount.transit.path
  name    = "${var.key_prefix}-worker-auth-storage"
  type    = "aes256-gcm96"
}

locals {
  controller_policies = concat([vault_policy.boundary_controller.name], var.token_policies_controller)
  worker_policies    = concat([vault_policy.boundary_worker.name], var.token_policies_worker)
}

resource "vault_policy" "boundary_controller" {
  name = "${var.key_prefix}-controller"

  policy = <<EOT
# Allow Boundary controllers to use encryption keys
path "${vault_mount.transit.path}/encrypt/${var.key_prefix}-root" {
  capabilities = ["create", "update"]
}

path "${vault_mount.transit.path}/decrypt/${var.key_prefix}-root" {
  capabilities = ["create", "update"]
}

path "${vault_mount.transit.path}/encrypt/${var.key_prefix}-worker-auth" {
  capabilities = ["create", "update"]
}

path "${vault_mount.transit.path}/decrypt/${var.key_prefix}-worker-auth" {
  capabilities = ["create", "update"]
}

%{if var.enable_recovery_key}
path "${vault_mount.transit.path}/encrypt/${var.key_prefix}-recovery" {
  capabilities = ["create", "update"]
}

path "${vault_mount.transit.path}/decrypt/${var.key_prefix}-recovery" {
  capabilities = ["create", "update"]
}
%{endif}

# Allow reading key configurations
path "${vault_mount.transit.path}/keys/${var.key_prefix}-*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "boundary_worker" {
  name = "${var.key_prefix}-worker"

  policy = <<EOT
# Allow workers to use their auth storage key
path "${vault_mount.transit.path}/encrypt/${var.key_prefix}-worker-auth-storage" {
  capabilities = ["create", "update"]
}

path "${vault_mount.transit.path}/decrypt/${var.key_prefix}-worker-auth-storage" {
  capabilities = ["create", "update"]
}

# Allow reading key configuration
path "${vault_mount.transit.path}/keys/${var.key_prefix}-worker-auth-storage" {
  capabilities = ["read"]
}
EOT
}

resource "vault_token_auth_backend_role" "boundary_controller" {
  role_name           = "${var.key_prefix}-controller"
  allowed_policies    = local.controller_policies
  token_period        = var.token_period
  renewable           = true
  token_explicit_max_ttl = 0
}

resource "vault_token_auth_backend_role" "boundary_worker" {
  role_name           = "${var.key_prefix}-worker"
  allowed_policies    = local.worker_policies
  token_period        = var.token_period
  renewable           = true
  token_explicit_max_ttl = 0
}

resource "vault_token" "boundary_controller" {
  role_name = vault_token_auth_backend_role.boundary_controller.role_name
  policies  = local.controller_policies
  renewable = true
  period    = var.token_period
}

resource "vault_token" "boundary_worker" {
  role_name = vault_token_auth_backend_role.boundary_worker.role_name
  policies  = local.worker_policies
  renewable = true
  period    = var.token_period
}