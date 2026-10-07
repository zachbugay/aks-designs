variable "config_file" {
  description = "Environment specific YAML configuration file."
  type        = string
}

variable "location" {
  description = "The Azure region for the specified resources."
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription Id"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant Id"
  type        = string
}
