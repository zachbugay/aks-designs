variable "workload" {
  description = "(Required) The usage or application of the Log Analytics Workspace."
  type        = string
  default     = ""
}

variable "environment" {
  description = "(Required) The environment of the Log Analytics Workspace."
  type        = string
  default     = ""
}

variable "location" {
  description = "(Required) The location/region where the Resource Group is created. Changing this forces a new resource to be created."
  type        = string
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Log Analytics Workspace."
  type        = string
}

variable "custom_name" {
  description = "(Optional) The name of the Log Analytics Workspace."
  type        = string
  default     = ""
}

variable "instance" {
  description = "(Optional) The instance count for the Log Analytics Workspace."
  type        = string
  default     = ""
}

variable "sku" {
  description = "(Optional) The SKU (tier) of the Log Analytics Workspace."
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "(Optional) The retention period in days for the logs that are collected by the Log Analytics service. Possible values range between 30 and 730 days."
  type        = number
  default     = 30
}

variable "allow_resource_only_permissions" {
  description = "(Optional) Specifies whether the access policy grants the 'Log Analytics Reader' role for built-in roles."
  type        = bool
  default     = false
}

variable "local_authentication_enabled" {
  description = "(Optional) Specifies whether local authentication should be disabled for the workspace."
  type        = bool
  default     = true
}

variable "daily_quota_gb" {
  description = "(Optional) The workspace daily quota in GB."
  type        = number
  default     = -1
}

variable "internet_ingestion_enabled" {
  description = "(Optional) Specifies whether or not ingestion from the Internet is enabled."
  type        = bool
  default     = true
}

variable "internet_query_enabled" {
  description = "(Optional) Specifies whether or not Internet access is enabled for the workspace."
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