variable "custom_name" {
  description = "(Optional) Custom name for the Application Gateway."
  type        = string
  default     = ""
}

variable "workload" {
  description = "(Optional) The usage or application of the Application Gateway."
  type        = string
  default     = ""
}

variable "environment" {
  description = "(Required) The environment of the Application Gateway."
  type        = string
}

variable "location" {
  description = "(Required) The location/region where the Application Gateway is created."
  type        = string
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group."
  type        = string
}

variable "instance" {
  description = "(Optional) The instance count."
  type        = string
  default     = ""
}

variable "sku" {
  description = "(Optional) The SKU of the Application Gateway. Accepted values are Basic, Standard_v2, and WAF_v2."
  type        = string
  default     = "Basic"
}

variable "sku_capacity" {
  description = "(Optional) The capacity (instance count) of the Application Gateway."
  type        = number
  default     = 2
}

variable "subnet_id" {
  description = "(Required) The ID of the subnet for the Application Gateway."
  type        = string
}

variable "public_ip_address_id" {
  description = "(Required) The ID of the public IP for the frontend."
  type        = string
}

variable "backend_ip_addresses" {
  description = "(Optional) List of backend IP addresses (e.g., Istio internal LB IP)."
  type        = list(string)
  default     = []
}

variable "backend_fqdns" {
  description = "(Optional) List of backend FQDNs."
  type        = list(string)
  default     = []
}

variable "waf_enabled" {
  description = "(Optional) Enable WAF on the Application Gateway. Only supported on WAF_v2 SKU."
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "(Optional) The WAF mode. Accepted values are Detection and Prevention."
  type        = string
  default     = "Prevention"
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