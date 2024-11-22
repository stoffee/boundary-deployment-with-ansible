output "transit_mount_path" {
  value = vault_mount.transit.path
  description = "Path where transit secrets engine is mounted"
}

output "key_names" {
  value = {
    root              = vault_transit_secret_backend_key.boundary_root.name
    worker_auth       = vault_transit_secret_backend_key.boundary_worker_auth.name
    recovery          = var.enable_recovery_key ? vault_transit_secret_backend_key.boundary_recovery[0].name : null
    worker_auth_storage = vault_transit_secret_backend_key.boundary_worker_auth_storage.name
  }
  description = "Names of created encryption keys"
}

output "boundary_controller_token" {
  value     = vault_token.boundary_controller.client_token
  sensitive = true
  description = "Token for Boundary controllers to access Vault"
}

output "boundary_worker_token" {
  value     = vault_token.boundary_worker.client_token
  sensitive = true
  description = "Token for Boundary workers to access Vault"
}
