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

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Virtual Network."
  type        = string
}

variable "admin_group_object_ids" {
  description = "(Optional) List of AAD group pboject IDs that will have admin role of the cluster."
  type        = set(string)
}

variable "enable_azure_rbac" {
  description = "(Optional) Whether to enable Azure RBAC for Kubernetes authorization."
  type        = bool
  default     = true
}

variable "entra_managed" {
  description = "(Optional) Whether to enable Managed Entra (AAD)"
  type        = bool
  default     = true
}

variable "tenant_id" {
  description = "(Required) Azure Tenant Id"
  type        = string
}

variable "dns_prefix" {
  description = "(Required) DNS prefix specified when creating the managed cluster."
  type        = string
  default     = ""
}

variable "dns_prefix_private_cluster" {
  description = "(Optional) DNS prefix specified when creating the managed cluster for private."
  type        = string
  default     = ""
}

variable "auto_upgrade_profile" {
  description = "(Optional) Manner in which OS and Cluster upgrades happen. By default, will be NodeImage and rapid. "
  type = object({
    node_os_upgrade_channel = optional(string, "NodeImage")
    upgrade_channel         = optional(string, "none")
  })
  default = {
    node_os_upgrade_channel = "NodeImage"
    upgrade_channel         = "rapid"
  }
}

variable "oidc_issuer_profile" {
  description = "(Optional) Whether the OIDC issuer is enabled."
  type = object({
    enabled = optional(bool)
  })
  default = {
    enabled = true
  }
}

variable "workload_identity" {
  description = "(Optional) Whether addon Workload Identity is enabled."
  type        = bool
  default     = true
}

variable "application_gateway_for_containers" {
  description = "(Optional) Enable the Application Gateway for Containers (ALB Controller) managed addon."
  type        = bool
  default     = false
}

variable "disable_local_accounts" {
  description = "(Optional) Whether local accounts are enabled enabled."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "(Optional) Kubernetes version"
  type        = string
  default     = "1.34.2"
}

variable "authorized_ip_ranges" {
  description = "(Optional) List of IP Address prefixes that are allowed to access the API server."
  type        = list(string)
}

variable "vm_size" {
  description = "(Optional) Default node pool VM size. Default Standard D2ds_v6"
  type        = string
  default = "Standard_D2as_v7"
}

variable "aks_vnet_id" {
  description = "(Required) Virtual Network ID"
  type        = string
}

variable "aks_cluster_subnet" {
  description = "(Required) Subnet of the user node pool."
  type        = string
}

variable "os_sku" {
  description = "(Optional) OS Sku to use. Default is AzureLinux."
  type        = string
  default     = "AzureLinux"
}

variable "container_registry_id" {
  description = "(Optional) Container Registry Kubelet Identity can pull from."
  type        = string
  default     = ""
}

variable "outbound_type" {
  description = "(Optional) The outbound (egress) routing method. Valid values are 'loadBalancer', 'userDefinedRouting', 'userAssignedNATGateway', 'managedNATGateway'. See https://learn.microsoft.com/azure/aks/egress-outboundtype"
  type        = string
  default     = "loadBalancer"
}

variable "log_analytics_workspace_id" {
  description = "(Optional) Resource ID of the Log Analytics Workspace."
  type        = string
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}

# https://learn.microsoft.com/en-us/azure/aks/istio-support-policy#service-mesh-add-on-release-calendar
variable "istio_revisions" {
  description = "(Optional) The list of Istio control plane revisions. Supports canary upgrades. See https://learn.microsoft.com/en-us/azure/aks/istio-upgrade"
  type        = list(string)
  default     = ["asm-1-28"]
}

variable "monitor_workspace_id" {
  type = string
}

variable "alert_email" {
  description = "(Optional) An email to send alerts to for AKS."
  type        = string
}

variable "random_string" {
  description = "(Optional) A random string suffix to ensure all resources in a deployment share the same identifier."
  type        = string
  default     = ""
}

variable "aks_lb_snet" {
  description = "(Optional) The azure resource ID of the aks-lb subnet."
  type = string
  default = null
}
