variable "workload" {
  description = "(Optional) The usage of the Hub."
  type        = string
  default     = "hub"
}

variable "workload_management" {
  description = "(Required) Management workload"
  type        = string
  default     = "mgt"
}

variable "environment" {
  description = "(Optional) The environment of the Hub."
  type        = string
  default     = "nonprod"
}

variable "workload_environment" {
  description = "(Optional) The environment of the workloads."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "(Required) The location/region where the Virtual Network is created. Changing this forces a new resource to be created."
  type        = string
}

variable "instance" {
  description = "(Optional) The instance count for the Hub."
  type        = string
  default     = "001"
}

variable "address_space_hub" {
  description = "(Required) The address space that is used the Hub."
  type        = list(string)
}

variable "dns_servers" {
  description = "(Optional) The DNS servers to be used with the Hub."
  type        = list(string)
  default     = null
}

variable "firewall" {
  description = "(Optional) Whether or not to use an Azure Firewall."
  type        = bool
  default     = false
}

variable "firewall_sku_name" {
  description = "(Optional) SKU name of the Firewall. Possible values are AZFW_Hub and AZFW_VNet. Changing this forces a new resource to be created."
  type        = string
  default     = "AZFW_Hub"
}

variable "firewall_sku_tier" {
  description = "(Optional) SKU tier of the Firewall. Possible values are Premium, Standard and Basic."
  type        = string
  default     = "Basic"
}

variable "gateway" {
  description = "(Optional) Include a Gateway."
  type        = bool
  default     = true
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

variable "p2s_vpn" {
  description = "(Optional) Include a Point-to-Site VPN configuration."
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

variable "nat_gateway_public_ip_count" {
  description = "(Optional) The number of count NAT Gateway public IPs."
  type        = number
  default     = 0
}

variable "key_vault" {
  description = "(Optional) Include a Key Vault."
  type        = bool
  default     = true
}

variable "ip_filter" {
  description = "(Optional) Include an IP Filter."
  type        = bool
  default     = true
}

variable "address_space_spokes" {
  description = "(Optional) The address space that is used the Virtual Network."
  type = list(object({
    workload         = string
    environment      = string
    instance         = string
    address_space    = list(string)
    virtual_machines = optional(bool, true)
  }))
  default = []
}

variable "spoke_dns" {
  description = "(Optional) Include a Spoke DNS."
  type        = bool
  default     = true
}

variable "address_space_spoke_dns" {
  description = "(Optional) The address space that is used the Virtual Network."
  type        = list(string)
  default     = null
}

variable "spoke_jumphost" {
  description = "(Optional) Include a Spoke Jump Host."
  type        = bool
  default     = false
}

variable "address_space_spoke_jumphost" {
  description = "(Optional) The address space that is used the Virtual Network."
  type        = list(string)
  default     = null
}

variable "spoke_dmz" {
  description = "(Optional) Include a DMZ Spoke."
  type        = bool
  default     = false
}

variable "address_space_spoke_dmz" {
  description = "(Optional) The address space that is used the Virtual Network."
  type        = list(string)
  default     = null
}

variable "address_space_spoke_aks" {
  description = "(Optional) The address space that is used the Virtual Network."
  type        = list(string)
  default     = null
}

variable "tenant_id" {
  description = "(Optional) Tenant ID for AKS"
  type        = string
  default     = null
}

variable "admin_group_object_ids" {
  description = "(Optional) Object ID of admin group for AKS."
  type        = list(string)
  default     = null
}

variable "authorized_ip_ranges" {
  type = list(string)
}

variable "web_application_firewall" {
  description = "(Optional) Include a WAF."
  type        = bool
  default     = false
}

variable "private_monitoring" {
  description = "(Optional) Include a Private Monitoring."
  type        = bool
  default     = false
}

variable "dependency_agent" {
  description = "(Optional) Install the Dependency Agent on spoke VMs? Note: Not supported on Ubuntu 24.04."
  type        = bool
  default     = false
}

variable "address_space_spoke_private_monitoring" {
  description = "(Optional) The address space that is used the Virtual Network."
  type        = list(string)
  default     = null
}

variable "connection_monitor" {
  description = "(Optional) Include a Network Watcher Connection Monitor."
  type        = bool
  default     = false
}

variable "update_management" {
  description = "(Optional) Include Update Management for the Virtual Machine."
  type        = bool
  default     = false
}

variable "backup" {
  description = "(Optional) Include a backup configuration for the Virtual Machine."
  type        = bool
  default     = false
}

variable "network_security_group" {
  description = "(Optional) Include a Network Security Group with Flow Log."
  type        = bool
  default     = false
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}

variable "alert_email" {
  description = "(Optional) An email to send alerts to for AKS."
  type        = string
}

variable "application_gateway" {
  description = "(Optional) Deploy an Application Gateway with WAF for inbound L7 traffic."
  type        = bool
  default     = false
}

variable "appgw_backend_ip_addresses" {
  description = "(Optional) Backend IP addresses for the Application Gateway (e.g., Istio internal LB IP)."
  type        = list(string)
  default     = []
}

variable "random_string" {
  description = "(Optional) A random string suffix to ensure all resources in a deployment share the same identifier."
  type        = string
  default     = ""
}

variable "application_gateway_for_containers" {
  description = "(Optional) Enable the Application Gateway for Containers (ALB Controller) managed addon."
  type        = bool
  default     = false
}

variable "vm_size" {
  description = "VM Size for AKS node pools."
  type        = string
  default     = "Standard_D2as_v7"
}