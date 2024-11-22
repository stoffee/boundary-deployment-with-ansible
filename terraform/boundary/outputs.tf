

# outputs.tf
output "org_scope_id" {
  value       = boundary_scope.org.id
  description = "The ID of the organization scope"
}

output "project_scope_ids" {
  value = {
    for name, project in boundary_scope.projects : name => project.id
  }
  description = "Map of project names to their scope IDs"
}

output "auth_method_id" {
  value       = boundary_auth_method.password.id
  description = "The ID of the password auth method"
}