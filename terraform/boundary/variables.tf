# variables.tf
variable "addr" {
  type        = string
  description = "The URL where Boundary is running"
}

variable "auth_method_id" {
  type        = string
  description = "The auth method ID to use for authentication"
}

variable "login_name" {
  type        = string
  description = "Login name for password auth"
}

variable "password" {
  type        = string
  description = "Password for auth"
  sensitive   = true
}

variable "organization_name" {
  type        = string
  description = "The name of your organization"
}

variable "projects" {
  type = map(object({
    description = string
  }))
  description = "Map of projects to create"
}

variable "global_admin_user_ids" {
  type        = list(string)
  description = "List of user IDs to grant global admin permissions"
}