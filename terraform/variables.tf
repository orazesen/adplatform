variable "provider" {
  description = "Infrastructure provider (hetzner, ovh, aws, gcp, azure)"
  type        = string
  default     = "hetzner"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
}

variable "region" {
  description = "Region/location for deployment"
  type        = string
}

variable "server_count" {
  description = "Total number of servers to provision"
  type        = number
  default     = 5
}

variable "server_type" {
  description = "Server type/instance size"
  type        = string
  default     = "CCX63"  # Hetzner: 64 vCPU, 256GB RAM
}

variable "private_network_cidr" {
  description = "CIDR block for private network"
  type        = string
  default     = "10.10.0.0/16"
}

variable "ssh_keys" {
  description = "List of SSH public keys"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    project    = "adplatform"
    managed_by = "terraform"
  }
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable automatic backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "additional_volumes" {
  description = "Additional storage volumes"
  type = list(object({
    size = number
    type = string
  }))
  default = []
}
