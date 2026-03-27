variable "environment" {
  description = "(required) The environment of the Key Vault."
  type        = string
}

variable "location" {
  description = "(Required) The location/region where the Key Vault is created. Changing this forces a new resource to be created."
  type        = string
}

variable "workload" {
  description = "(Required) The usage or application of the Key Vault."
  type        = string
}

variable "custom_name" {
  description = "(Optional) Custom name for the Key Vault."
  type        = string
  default     = ""
}

variable "instance" {
  description = "(Optional) The instance count for the Key Vault."
  type        = string
  default     = "001"
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Key Vault."
  type        = string
}

variable "sku_name" {
  description = "(Optional) Azure Key Vault Sku: standard or premium."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be one of: 'standard', 'premium'"
  }
}

variable "tenant_id" {
  description = "(Required) Azure Tenant Id"
  type        = string
}

variable "enabled_for_disk_encryption" {
  description = "(Optional) Is Disk Encryption Enabled for this Key Vault?"
  type        = bool
  default     = false
}

variable "enabled_for_deployment" {
  description = "(Optional) Is Deployment Enabled for this Key Vault?"
  type        = bool
  default     = false
}

variable "enabled_for_template_deployment" {
  description = "(Optional) Is Template Deployment Enabled for this Key Vault?"
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "(Optional) The number of days that items should be retained for once soft-deleted. Must be between 7 and 90."
  type        = number
  default     = 90
}

variable "purge_protection_enabled" {
  description = "(Optional) Is Purge Protection Enabled for this Key Vault?"
  type        = bool
  default     = false
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = {}
}

variable "random_string" {
  description = "(Optional) A random string suffix to ensure all resources in a deployment share the same identifier."
  type        = string
  default     = ""
}

variable "private_endpoint_subnet_resource_id" {
  description = "(Required) The resource ID of the hub subnet in which to create the private endpoint."
  type        = string
}

variable "key_vault_private_dns_zone_resource_id" {
  description = "(Optional) The resource ID of the privatelink.vaultcore.azure.net Private DNS Zone to register the private endpoint in. When null, no DNS zone group is created."
  type        = string
  default     = null
}

variable "public_network_access_enabled" {
  description = "(Optional) Whether or not the key vault should have a public endpoint. Defaults to false."
  type        = bool
  default     = false
}

variable "key_vault_administrators" {
  description = "(Optional) List of object IDs who should be granted key vault admin roles."
  type        = list(string)
  default     = []
}
