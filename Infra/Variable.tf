variable "location" {
  description = "Azure region for Cedarbridge resources"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Name of the Cedarbridge project"
  type        = string
  default     = "cedarbridge"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
variable "sql_admin_password" {
  description = "Administrator password for the SQL logical server"
  type        = string
  sensitive   = true
  ephemeral   = true
} 