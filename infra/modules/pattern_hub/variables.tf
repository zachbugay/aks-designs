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

variable "gateway" {
  description = "(Optional) Include a Gateway."
  type        = bool
  default     = false
}

variable "gateway_type" {
  description = "(Optional) The type of the Gateway."
  type        = string
  default     = "Vpn"
}

variable "gateway_sku" {
  description = "(Optional) The SKU of the Gateway."
  type        = string
  default     = "VpnGw1AZ"
}

variable "asn" {
  description = "(Optional) The ASN of the Gateway."
  type        = number
  default     = 0
}

variable "p2s_vpn" {
  description = "(Optional) Include a Point-to-Site VPN configuration."
  type        = bool
  default     = false
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
  type        = bool
  default     = false
}

variable "firewall_sku_name" {
  description = "(Optional) SKU name of the Firewall. Possible values are AZFW_Hub and AZFW_VNet. Changing this forces a new resource to be created."
  type        = string
  default     = "AZFW_VNet"
}

variable "firewall_sku_tier" {
  description = "(Optional) SKU tier of the Firewall. Possible values are Premium, Standard and Basic."
  type        = string
  default     = "Basic"
}

variable "firewall_default_rules" {
  description = "(Optional) Include the default rules for the Firewall."
  type        = bool
  default     = true
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

variable "application_gateway" {
  description = "(Optional) Deploy an Application Gateway for inbound L7 traffic."
  type        = bool
  default     = false
}

variable "appgw_backend_ip_addresses" {
  description = "(Optional) Backend IP addresses for the Application Gateway (e.g., Istio internal LB IP)."
  type        = list(string)
  default     = []
}

variable "appgw_waf_enabled" {
  description = "(Optional) Enable WAF on the Application Gateway. Only supported on WAF_v2 SKU."
  type        = bool
  default     = false
}

variable "appgw_waf_mode" {
  description = "(Optional) The WAF mode. Accepted values are Detection and Prevention."
  type        = string
  default     = "Prevention"
}

variable "random_string" {
  description = "(Optional) A random string suffix to ensure all resources in a deployment share the same identifier."
  type        = string
  default     = ""
}