# main.tf
terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.0"
    }
  }
}

provider "boundary" {
  addr                            = var.addr
  auth_method_id                  = var.auth_method_id
  password_auth_method_login_name = var.login_name
  password_auth_method_password   = var.password
}

# 🏰 Create the org scope - Our top-level kingdom!
resource "boundary_scope" "org" {
  name                     = var.organization_name
  description             = "The magical realm of ${var.organization_name} 🏰"
  scope_id                = "global"
  auto_create_admin_role  = true
  auto_create_default_role = true
}

# 🌟 Create project scopes - Like different areas of our kingdom
resource "boundary_scope" "projects" {
  for_each                = var.projects
  name                    = each.key
  description             = each.value.description
  scope_id                = boundary_scope.org.id
  auto_create_admin_role  = true
}

# 👥 Auth Methods - The castle's security system!
resource "boundary_auth_method" "password" {
  name        = "org_password_auth"
  description = "Password auth for ${var.organization_name} 🔑"
  type        = "password"
  scope_id    = boundary_scope.org.id
}

# 🧙‍♂️ Create some roles - Like giving people special powers!
resource "boundary_role" "global_admin" {
  name        = "global_admin"
  description = "Global admin role 👑"
  scope_id    = "global"
  grant_strings = [
    "id=*;type=*;actions=*"
  ]
  principal_ids = var.global_admin_user_ids
}

# 🎭 Create managed groups - Like organizing our kingdom's citizens
resource "boundary_managed_group" "project_users" {
  for_each       = boundary_scope.projects
  name           = "${each.key}_users"
  description    = "Managed group for ${each.key} users 👥"
  auth_method_id = boundary_auth_method.password.id
}

