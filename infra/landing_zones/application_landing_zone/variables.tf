variable "aks_node_pool_vm_size" {
  description = "value of azure kubernetes node pool vm size"
  type        = string
  default     = "Standard_D4as_v7"
}

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

variable "application_gateway_trusted_root_certificate_base64" {
  description = <<-EOT
    (Optional) Base64 encoded PEM of the CA that signs the backend TLS certificates presented by
    the in-cluster gateway. Application Gateway v2 marks private-CA backends unhealthy unless this
    root is uploaded. The value is the demo-ca Secret's ca.crt field verbatim; see the backend TLS
    trusted root bootstrap section of README.md. When empty, the default trusted certificate
    authorities are used.
  EOT
  type        = string
  default     = ""
}
