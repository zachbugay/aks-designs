variable "aks_node_pool_vm_size" {
  description = "value of azure kubernetes node pool vm size"
  type        = string
  default     = "Standard_D4as_v7"
}

variable "aks_version" {
  description = "(Optional) Kubernetes version"
  type        = string
  default     = "1.36.3"
}

variable "aks_spoke_vnet_address_space" {
  description = "(Required) AKS Spoke VNet address space."
  type        = string
  default     = ""
}

variable "aks_environment" {
  description = "Environment name for shared resources."
  type        = string
  default     = "nonprod"
}

variable "location" {
  description = "The Azure region for the specified resources."
  type        = string
}

variable "firewall_enabled" {
  description = "Whether Azure Firewall is enabled."
  type        = bool
  default     = true
}

variable "firewall_private_ip" {
  description = "(Required) Private IP address to the Azure Firewall."
  type = string
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

variable "alert_email" {
  description = "(Optional) An email to send alerts."
  type        = string
  default     = null
}

variable "virtual_network_gateway_exists" {
  description = "(Optional) Is there a Virtual Network Gateway?"
  type        = bool
  default     = true
}

variable "hub_resource_group_name" {
  description = "(Required) Resource group name of the hub."
  type = string  
}

variable "hub_virtual_network_id" {
  description = "(Required) Resource ID for the hub virtual network."
  type = string  
}

variable "hub_log_analytics_workspace_id" {
  description = "(Required) Resource ID for the hub log analytics workspace."
  type = string
}

variable "hub_azure_monitor_workspace_id" {
  description = "(Required) Resource ID for the hub azure montior workspace."
  type = string
}

variable "private_endpoint_subnet_id" {
  description = "(Required) Resource ID for subnet in which to add private endpoints."
  type = string
}

variable "private_dns_zones" {
  description = "(Required) Map of private DNS zones."
  type = map(object({
    name = string
    id = string
  }))
}

variable "instance" {
  description = "(Optional) The instance count for the Hub."
  type        = string
  default     = "001"
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}

variable "enable_private_api_server" {
  description = "(Optional) Whether or not the Kubernetes API Server should be privately accessible"
  type        = bool
  default     = true
}

variable "application_gateway" {
  description = "(Optional) Deploy an Application Gateway in front of the cluster's in-cluster gateway."
  type        = map({
    enabled = bool
    backend_ip_addresses = list(string)
    certificate_common_name = optional(string)
    trusted_root_certificate_pem = optional(string)
  })
  default     = {
    enabled = false
    backend_ip_addresses = []
    certificate_common_name = null
    trusted_root_certificate_pem = null
  }
}

variable "application_gateway_applications" {
  description = "(Optional) Applications published through the Application Gateway. Required when application_gateway.enabled is true."
  type = map(object({
    hostname                  = string
    https_port                = optional(number, 443)
    http_port                 = optional(number, 80)
    probe_path                = string
    probe_protocol            = optional(string, "Https")
    probe_interval            = optional(number, 30)
    probe_timeout             = optional(number, 30)
    probe_unhealthy_threshold = optional(number, 3)
    probe_status_codes        = optional(list(string), ["200-399"])
    backend_port              = optional(number, 443)
    backend_protocol          = optional(string, "Https")
    backend_request_timeout   = optional(number, 30)
    cookie_based_affinity     = optional(string, "Disabled")
    rule_type                 = optional(string, "Basic")
    redirect_type             = optional(string, "Permanent")
    path_rules = optional(list(object({
      name        = string
      paths       = list(string)
      backend_app = optional(string)
    })), [])
    https_rule_priority         = number
    http_redirect_rule_priority = number
  }))
  default = {}
}

variable "dns_servers" {
  type = list(string)
}

variable "authorized_ip_ranges" {
  description = "(Optional) IP Address ranges to grant access to the cluster."
  type        = list(string)
  default     = null
}