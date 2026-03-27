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
    Owner       = ""
    environment = ""
    department  = ""
  }
}

variable "tenant_id" {
  description = "Azure Tenant Id"
  type        = string
}

variable "admin_group_object_ids" {
  description = "(Optional) Comma-delimited string of admin group object IDs for AKS."
  type        = string
  default     = ""
}

variable "virtual_network_gateway" {
  description = "(Optional) Include a Virtual Network Gateway for VPN (P2S/S2S/ER) connectivity?"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "(Optional) An email to send alerts to for AKS."
  type        = string
  default     = null
}

variable "firewall" {
  description = "(Optional) Use Azure Firewall?"
  type        = bool
  default     = false
}
