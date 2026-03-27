variable "environment" {
  description = "(required) The environment of the Resource Group."
  type        = string
}

variable "location" {
  description = "(Required) The location/region where the Resource Group is created. Changing this forces a new resource to be created."
  type        = string
}

variable "workload" {
  description = "(Required) The usage or application of the Resource Group."
  type        = string
  default     = ""
}

variable "custom_name" {
  description = "(Optional) The name of the Resource Group."
  type        = string
  default     = ""
}

variable "instance" {
  description = "(Optional) The instance count for the Resource Group."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Virtual Network."
  type        = string
}

variable "tenant_id" {
  description = "(Required) Azure Tenant Id"
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

variable "public_network_access_enabled" {
  description = "(Optional) Whether public network access is enabled. Default is false."
  type        = bool
  default     = false
}

variable "network_acls" {
  description = "(Optional) A list of Network ACLs which should be set on the Key Vault."
  type = list(object({
    bypass                     = string
    default_action             = string
    ip_rules                   = list(string)
    virtual_network_subnet_ids = list(string)
  }))
  default = []
}

variable "rbac_authorization_enabled" {
  description = "(Required) Only RBAC is going to work here. Access Policies are forbidden."
  type        = bool
  default     = true
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}

variable "random_string" {
  description = "(Optional) A random string suffix to ensure all resources in a deployment share the same identifier."
  type        = string
  default     = ""
}
