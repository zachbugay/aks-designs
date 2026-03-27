variable "environment" {
  description = "(Required) The environment of the Azure Monitor Workspace."
  type        = string
}

variable "location" {
  description = "(Required) The location/region where the Azure Monitor Workspace is created. Changing this forces a new resource to be created."
  type        = string
}

variable "resource_group_name" {
  description = "(Required) The name of the Resource Group where the Azure Monitor Workspace should exist."
  type        = string
}

variable "workload" {
  description = "(Optional) The usage or application of the Azure Monitor Workspace."
  type        = string
  default     = ""
}

variable "custom_name" {
  description = "(Optional) Custom name override for the Azure Monitor Workspace."
  type        = string
  default     = ""
}

variable "instance" {
  description = "(Optional) The instance count for the Azure Monitor Workspace."
  type        = string
  default     = ""
}

variable "public_network_access_enabled" {
  description = "(Optional) Whether public network access is enabled for the Azure Monitor Workspace."
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