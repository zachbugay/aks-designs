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

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Virtual Network."
  type        = string
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

variable "bgp_route_propagation_enabled" {
  description = "(Optional) Should BGP route propagation be enabled? Defaults to true."
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