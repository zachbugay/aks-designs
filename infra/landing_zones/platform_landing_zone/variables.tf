variable "location" {
  description = "The Azure region for the specified resources."
  type        = string
}

variable "environment" {
  description = "Environment name for shared resources."
  type        = string
  default     = "nonprod"
}

variable "workload_environment" {
  description = "Environment name for the workloads."
  type        = string
  default     = "dev"
}

variable "subscription_id" {
  description = "Azure Subscription Id"
  type        = string
}

variable "common_tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default = {
    owner       = "Tech Team"
    environment = "nonprod"
    department  = "TechTeam"
  }
}

variable "tenant_id" {
  description = "Azure Tenant Id"
  type        = string
}

variable "admin_object_ids" {
  description = "(Optional) Comma-delimited string of admin group object IDs for AKS."
  type        = string
  default     = ""
}

variable "virtual_network_gateway" {
  description = "(Optional) Include a Virtual Network Gateway for VPN (P2S/S2S/ER) connectivity?"
  type        = bool
  default     = false
}

variable "point_to_site_vpn" {
  description = "(Optional) Include a P2S VPN for connectivity?"
  type        = bool
  default     = false
}

variable "nat_gateway_public_ip_count" {
  description = "(Optional) Number of public IPs for the NAT Gateway."
  type        = number
  default     = 1
}

variable "alert_email" {
  description = "(Optional) An email to send alerts."
  type        = string
  default     = null
}

variable "firewall" {
  description = "(Optional) Whether or not to use an Azure Firewall."
  type = object({
    enabled       = bool
    sku_tier      = string
    sku_name      = string
    default_rules = bool
  })
  default = {
    enabled       = true
    sku_tier      = "Standard"
    sku_name      = "AZFW_VNet"
    default_rules = true
  }
}
