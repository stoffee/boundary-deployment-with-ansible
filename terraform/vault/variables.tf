variable "transit_mount_path" {
  type        = string
  description = "Path where the transit secrets engine will be mounted"
  default     = "transit"
}

variable "key_prefix" {
  type        = string
  description = "Prefix for Boundary encryption keys"
  default     = "boundary"
}

variable "token_period" {
  type        = string
  description = "Token renewal period for Boundary auth tokens"
  default     = "24h"
}

variable "token_policies_controller" {
  type        = list(string)
  description = "Additional policies to attach to controller token"
  default     = []
}

variable "token_policies_worker" {
  type        = list(string)
  description = "Additional policies to attach to worker token"
  default     = []
}

variable "enable_recovery_key" {
  type        = bool
  description = "Enable creation of recovery encryption key"
  default     = true
}