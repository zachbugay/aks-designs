variable "workload" {
  description = "(Required) The usage or application of the AKS spoke."
  type        = string
}

variable "environment" {
  description = "(Required) The environment of the AKS spoke."
  type        = string
}

variable "location" {
  description = "(Required) The location/region where the AKS spoke is created. Changing this forces a new resource to be created."
  type        = string
}

variable "instance" {
  description = "(Optional) The instance count for the AKS spoke."
  type        = string
  default     = "001"
}

variable "address_space" {
  description = "(Required) The address space that is used the AKS spoke."
  type        = list(string)
}

variable "dns_servers" {
  description = "(Optional) The DNS servers to be used with the AKS spoke."
  type        = list(string)
  default     = null
}

variable "tenant_id" {
  description = "Azure Tenant Id for Entra RBAC."
  type        = string
}

variable "admin_object_ids" {
  description = "List of object IDs to be assigned admin over the AKS cluster."
  type        = list(string)
}

variable "vm_size" {
  description = "VM Size of all node pools."
  type        = string
  default     = "Standard_D2as_v7"
}

variable "authorized_ip_ranges" {
  description = "(Optional) IP Address ranges to grant access to the cluster."
  type        = list(string)
  default     = null
}

variable "firewall" {
  description = "(Optional) Firewall in Hub?"
  type        = bool
  default     = false
}

variable "network_security_group" {
  description = "(Optional) Include a Network Security Group."
  type        = bool
  default     = false
}

variable "network_security_rules" {
  description = "(Optional) A list of Network Security Rules."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = [
    {
      name                       = "A-IN-Net10-Net10"
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "10.0.0.0/8"
    },
    {
      name                       = "A-IN-AzureLoadBalancer-Any"
      priority                   = 4095
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    },
    {
      name                       = "D-IN-Any-Any"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "A-OUT-Net10-Net10"
      priority                   = 1000
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "10.0.0.0/8"
    },
    {
      name                       = "A-OUT-Net10-Internet-TCP-80"
      priority                   = 1005
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "Internet"
    },
    {
      name                       = "A-OUT-Net10-Internet-TCP-443"
      priority                   = 1010
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "Internet"
    },
    {
      name                       = "A-OUT-Net10-AzureKMS1-TCP-1688"
      priority                   = 1015
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1688"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "20.118.99.224"
    },
    {
      name                       = "A-OUT-Net10-AzureKMS2-TCP-1688"
      priority                   = 1020
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1688"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "40.83.235.53"
    },
    {
      name                       = "A-OUT-Net10-AzureNTP1-UDP-123"
      priority                   = 1025
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_range     = "123"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "51.145.123.29"
    },
    {
      name                       = "A-OUT-Net10-AzureNTP2-UDP-123"
      priority                   = 1030
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_range     = "123"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "51.137.137.111"
    },
    {
      name                       = "D-OUT-Any-Any"
      priority                   = 4096
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace to log Application Gateway."
  type        = string
  default     = ""
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}

variable "hub_virtual_network_id" {
  description = "(Required) Hub AKS spoke ID for VNet peering."
  type        = string
}

variable "hub_resource_group_name" {
  description = "(Required) Hub resource group name for VNet peering."
  type        = string
}

variable "gateway_exists" {
  description = "(Optional) Is there a Virtual Network Gateway?"
  type        = bool
  default     = false
}

variable "subnets_next_hop" {
  description = "(Optional) The default next hop of the Virtual Network."
  type        = string
  default     = null
}

variable "monitor_workspace_id" {
  description = "The ID of the Azure Monitor Workspace."
  type        = string
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

variable "application_gateway_for_containers" {
  description = "(Optional) Enable the Application Gateway for Containers (ALB Controller) managed addon."
  type        = bool
  default     = false
}
variable "key_vault_private_dns_zone_resource_id" {
  description = "(Optional) The resource ID of the privatelink.vaultcore.azure.net Private DNS Zone to register the Key Vault private endpoint in."
  type        = string
  default     = null
}

variable "enable_private_api_server" {
  description = "(Optional) Whether or not the Kubernetes API Server should be privately accessible"
  type        = bool
  default     = false
}

variable "private_dns_zone_id" {
  description = "(Optional) Private DNS Zone ID the AKS Private API Server."
  type        = string
  default     = ""
}


variable "application_gateway" {
  description = "(Optional) Deploy an Application Gateway in front of the cluster's in-cluster gateway."
  type        = bool
  default     = false
}

variable "application_gateway_backend_ip_addresses" {
  description = "(Optional) The backend IP addresses of the Application Gateway, typically the internal load balancer IP of the in-cluster gateway."
  type        = list(string)
  default     = []
}

variable "application_gateway_certificate_common_name" {
  description = "(Optional) The common name of the self signed Application Gateway frontend certificate. Defaults to the first hostname in application_gateway_applications."
  type        = string
  default     = null
}

variable "application_gateway_trusted_root_certificate_pem" {
  description = "(Optional) PEM encoded root certificate that signs the backend TLS certificates presented by the in-cluster gateway. When null, the default trusted certificate authorities are used."
  type        = string
  default     = null
}

variable "application_gateway_applications" {
  description = "(Optional) Applications published through the Application Gateway. Required when application_gateway is true."
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
