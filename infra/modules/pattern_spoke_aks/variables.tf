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

variable "admin_group_object_ids" {
  description = "List of object IDs to be assigned admin over the AKS cluster."
  type        = list(string)
}

variable "vm_size" {
  description = "VM Size of all node pools."
  type        = string
  default     = "Standard_D2as_v7"
}

variable "authorized_ip_ranges" {
  description = "IP Address ranges to grant access to the cluster."
  type        = list(string)
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