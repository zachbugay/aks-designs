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

variable "workload_management" {
  description = "(Required) Management workload"
  type        = string
  default     = "mgt"
}

variable "address_space" {
  description = "(Required) The address space that is used the Hub."
  type        = list(string)
}

variable "dns_servers" {
  description = "(Optional) The DNS servers to be used."
  type        = list(string)
  default     = null
}

variable "virtual_network_gateway" {
  description = "(Optional) Include a VPN Gateway."
  type        = bool
  default     = false
}

variable "virtual_network_gateway_type" {
  description = "(Optional) The type of the VPN Gateway."
  type        = string
  default     = "Vpn"
}

variable "virtual_network_gateway_sku" {
  description = "(Optional) The SKU of the VPN Gateway."
  type        = string
  default     = "VpnGw1AZ"
}

variable "asn" {
  description = "(Optional) The ASN of the VPN Gateway."
  type        = number
  default     = 0
}

variable "p2s_vpn" {
  description = "(Optional) Include a Point-to-Site VPN configuration."
  type        = bool
  default     = false
}

variable "vpn_auth_types" {
  description = "(Optional) The Point-to-Site authentication types to enable on the Virtual Network Gateway."
  type        = list(string)
  default     = ["AAD"]
}

variable "p2s_root_certificates" {
  description = "(Optional) Map of Point-to-Site root certificate name to base64 encoded DER public certificate data."
  type        = map(string)
  default     = {}
}

variable "gateway_active_active" {
  description = "(Optional) Active active configuration?"
  type        = bool
  default     = false
}

variable "bastion" {
  description = "(Optional) Include a Bastion Host."
  type        = bool
  default     = true
}

variable "bastion_sku" {
  description = "(Optional) The SKU of the Bastion Host."
  type        = string
  default     = "Basic"
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

variable "nat_gateway_public_ip_count" {
  description = "(Optional) The number of count NAT Gateway public IPs."
  type        = number
  default     = 0
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

variable "storage_account" {
  description = "(Optional) Include a Storage Account."
  type        = bool
  default     = true
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}

variable "deployment_token" {
  description = "(Optional) A random string suffix to ensure all resources in a deployment share the same identifier."
  type        = string
  default     = ""
}
