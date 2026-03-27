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

variable "admin_object_ids" {
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
  description = <<DESCRIPTION
(Optional) Manner in which OS and Cluster upgrades happen, and the window they are allowed to run in.
  - `node_os_upgrade_channel`: Channel used for node OS image upgrades.
  - `upgrade_channel`: Channel used for Kubernetes version upgrades. Use "none" to disable.
  - `maintenance_window`: When the upgrades above are allowed to run.
    https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#maintenance_window_auto_upgrade-1
  DESCRIPTION
  type = object({
    node_os_upgrade_channel = optional(string, "NodeImage")
    upgrade_channel         = optional(string, "none")
    maintenance_window = object({
      frequency    = string
      interval     = number
      duration     = number
      day_of_week  = optional(string)
      day_of_month = optional(number)
      week_index   = optional(string)
      start_time   = optional(string)
      utc_offset   = optional(string)
      start_date   = optional(string)
      not_allowed = optional(list(object({
        start = string
        end   = string
      })), [])
    })
  })

  default = {
    node_os_upgrade_channel = "NodeImage"
    upgrade_channel         = "rapid"
    maintenance_window = {
      # frequency "Daily" has no day_of_week in the AKS API, so leaving it set produces a
      # perpetual diff: Azure always returns it empty.
      frequency  = "Daily"
      interval   = 1
      duration   = 4
      start_time = "08:30"
      utc_offset = "-05:00" # EST
    }
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

variable "private_api_server" {
  description = "(Optional) Whether or not the Azure Kubernetes Services Control Plane should be private."
  type        = bool
  default     = false
}

variable "private_api_server_subnet_id" {
  description = "(Optional) Subnet ID for the AKS Private API Server."
  type        = string
  default     = ""
}

variable "private_dns_zone_id" {
  description = "(Optional) Private DNS Zone ID the AKS Private API Server."
  type        = string
  default     = ""
}

variable "authorized_ip_ranges" {
  description = "(Optional) List of IP Address prefixes that are allowed to access the API server."
  type        = list(string)
  default     = null
}

variable "vm_size" {
  description = "(Optional) Default node pool VM size. Default Standard_D4as_v7"
  type        = string
  default     = "Standard_D4as_v7"
}

variable "aks_vnet_id" {
  description = "(Required) Virtual Network ID"
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
# https://github.com/Azure/terraform-azurerm-avm-res-containerservice-managedcluster/blob/main/variables.tf#L1332
variable "service_mesh_profile" {
  description = <<DESCRIPTION
Service mesh profile for the cluster.
  - `istio`: Istio service mesh configuration
    - `enabled`: Whether or not Isito should be enabled.
    - `istio_revision`: One, or two Istio control plane revisions. When not upgrading, there is only one revision.
        When upgrading, there can only be two **consecutive** values. 
        For the initial deployment, only one value maybe present.
        Additional information: https://learn.microsoft.com/en-us/azure/aks/istio-upgrade
    - `internal_ingress_gateway_enabled`: Should Istio Internal Ingress Gateway be enabled?
    - `external_ingress_gateway_enabled`: Should Istio External Ingress Gateway be enabled?
  DESCRIPTION
  type = object({
    istio = object({
      enabled                          = bool
      istio_revision                   = string
      internal_ingress_gateway_enabled = bool
      external_ingress_gateway_enabled = bool
    })
  })

  default = {
    istio = {
      enabled                          = false
      istio_revision                   = ""
      internal_ingress_gateway_enabled = false
      external_ingress_gateway_enabled = false
    }
  }
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

variable "aks_alb_snet" {
  description = "(Optional) The azure resource ID of the aks-alb subnet."
  type        = string
  default     = null
}

variable "sku" {
  description = "(Optional) AKS SKU: 'Free', 'Standard', 'Premium'. Defaults to 'Free'."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku)
    error_message = "sku must be one of: 'Free', 'Standard', 'Premium'"
  }
}

variable "os" {
  description = "(Optional) OS SKU. Either: 'AzureLinux', 'Ubuntu'. Defaults to 'AzureLinux'"
  type        = string
  default     = "AzureLinux"

  validation {
    condition     = contains(toset(["AzureLinux", "Ubuntu"]), var.os)
    error_message = "os must be one of: 'AzureLinux', 'Ubuntu'"
  }
}


variable "system_node_pool" {
  description = "(Optional) User node pools that should also be created."
  type = object({
    name                         = string
    vm_size                      = string
    zones                        = set(string)
    os                           = string
    min_count                    = number
    max_count                    = number
    max_pods                     = number
    vnet_subnet_id               = optional(string, "")
    only_critical_addons_enabled = bool
  })

  validation {
    condition     = contains(toset(["AzureLinux", "Ubuntu"]), var.system_node_pool.os)
    error_message = "os must be one of: 'AzureLinux', 'Ubuntu'"
  }

  # validation {
  #   condition     = alltrue([for pool in var.system_node_pool : length(pool.name) >= 1 && length(pool.name) <= 12])
  #   error_message = "Each user node pool 'name' must be between 1 and 12 characters long."
  # }
  #
  # validation {
  #   condition     = alltrue([for pool in var.system_node_pool : can(regex("^[a-z][a-z0-9]*$", pool.name))])
  #   error_message = "Each user node pool 'name' must begin with a lowercase letter and contain only lowercase alphanumeric characters."
  # }
}

variable "user_node_pools" {
  description = "(Optional) User node pools that should also be created."
  type = map(object({
    name           = string
    node_count     = number
    vm_size        = string
    os             = string
    vnet_subnet_id = optional(string, "")
    upgrade_settings = optional(object({
      drain_timeout_in_minutes      = number
      max_surge                     = string
      node_soak_duration_in_minutes = number
      }),
      {
        drain_timeout_in_minutes      = 0
        max_surge                     = "10%"
        node_soak_duration_in_minutes = 0
    })
  }))

  validation {
    condition     = alltrue([for pool in var.user_node_pools : length(pool.name) >= 1 && length(pool.name) <= 12])
    error_message = "Each user node pool 'name' must be between 1 and 12 characters long."
  }

  validation {
    condition     = alltrue([for pool in var.user_node_pools : can(regex("^[a-z][a-z0-9]*$", pool.name))])
    error_message = "Each user node pool 'name' must begin with a lowercase letter and contain only lowercase alphanumeric characters."
  }
}

variable "addons_profile" {
  type = object({
    advanced_network_policies = object({
      enabled = bool
      observability = object({
        enabled = bool
      })
      performance = object({
        accelerationMode = string # 'BpfVeth' or 'None'
      })
      security = object({
        enabled                 = bool
        advancedNetworkPolicies = string # 'L7', 'FQDN' or 'None'
        cilium_mtls = object({
          enabled = bool
        })
      })
    })
    # Application Gateway for Containers with the Gateway API.
    application_gateway_for_containers = object({
      enabled = bool
    })
    # https://learn.microsoft.com/en-us/azure/aks/app-routing-gateway-api
    # Deploys the managed Istio control plane behind the `approuting-istio` GatewayClass.
    # The legacy NGINX ingress controller is always disabled.
    application_routing_gateway_api = object({
      enabled = bool
    })
    # https://learn.microsoft.com/en-us/azure/aks/node-autoprovision
    node_auto_provisioning = object({
      enabled = bool
    })
  })

  # Default is disabled.
  default = {
    advanced_network_policies = {
      enabled = true
      observability = {
        enabled = true
      }
      performance = {
        accelerationMode = "BpfVeth"
      }
      security = {
        enabled                 = true
        advancedNetworkPolicies = "FQDN"
        cilium_mtls = {
          enabled = true
        }
      }
    }
    application_gateway_for_containers = {
      enabled = false
    }
    application_routing_gateway_api = {
      enabled = false
    }
    node_auto_provisioning = {
      enabled = false
    }
  }
}
