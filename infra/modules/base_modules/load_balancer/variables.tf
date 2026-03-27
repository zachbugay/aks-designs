variable "custom_name" {
  description = "(Optional) Custom name for the Load Balancer."
  type        = string
  default     = ""
}

variable "workload" {
  description = "(Optional) The usage or application of the Load Balancer."
  type        = string
  default     = ""
}

variable "environment" {
  description = "(Required) The environment of the Load Balancer."
  type        = string
}

variable "location" {
  description = "(Required) The location/region where the Load Balancer is created."
  type        = string
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Load Balancer."
  type        = string
}

variable "instance" {
  description = "(Optional) The instance count for the Load Balancer."
  type        = string
  default     = ""
}

variable "sku" {
  description = "(Optional) The SKU of the Load Balancer. Accepted values are Basic and Standard."
  type        = string
  default     = "Standard"
}

variable "public_ip_address_id" {
  description = "(Optional) The ID of a Public IP Address for the frontend. Required for public LB."
  type        = string
  default     = null
}

variable "frontend_name" {
  description = "(Optional) The name of the frontend IP configuration."
  type        = string
  default     = "frontend"
}

variable "backend_pool_name" {
  description = "(Optional) The name of the backend address pool."
  type        = string
  default     = "backend"
}

variable "probe_name" {
  description = "(Optional) The name of the health probe."
  type        = string
  default     = "health"
}

variable "probe_protocol" {
  description = "(Optional) The protocol of the health probe."
  type        = string
  default     = "Tcp"
}

variable "probe_port" {
  description = "(Optional) The port of the health probe."
  type        = number
  default     = 22
}

variable "probe_interval" {
  description = "(Optional) The interval in seconds between health probes."
  type        = number
  default     = 5
}

variable "probe_number_of_probes" {
  description = "(Optional) The number of failed probes before the backend is considered unhealthy."
  type        = number
  default     = 2
}

variable "lb_rules" {
  description = "(Optional) A map of load balancer rules."
  type = map(object({
    protocol      = string
    frontend_port = number
    backend_port  = number
  }))
  default = {}
}

variable "disable_outbound_snat" {
  description = "(Optional) Disable outbound SNAT on LB rules. Set to true when NAT Gateway handles outbound."
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