variable "custom_name" {
  description = "(Optional) The name of the Virtual Network."
  type        = string
  default     = ""
}

variable "workload" {
  description = "(Optional) The usage or application of the Virtual Network."
  type        = string
  default     = ""
}

variable "environment" {
  description = "(Optional) The environment of the Virtual Network."
  type        = string
  default     = ""
}

variable "location" {
  description = "(Required) The location/region where the Virtual Network is created. Changing this forces a new resource to be created."
  type        = string
}

variable "instance" {
  description = "(Optional) The instance count for the Virtual Network."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Virtual Network."
  type        = string
}

variable "custom_network_interface_name" {
  description = "(Optional) The name of the Network Interface."
  type        = string
  default     = ""
}

variable "enable_ip_forwarding" {
  description = "(Optional) Should IP Forwarding be enabled on the Network Interface?"
  type        = bool
  default     = false
}

variable "enable_accelerated_networking" {
  description = "(Optional) Should Accelerated Networking be enabled on the Network Interface?"
  type        = bool
  default     = false
}

variable "ip_configuration_name" {
  description = "(Optional) The name of the IP Configuration."
  type        = string
  default     = "ipconfig"
}

variable "private_ip_address_allocation" {
  description = "(Optional) The allocation method of the Private IP Address."
  type        = string
  default     = "Dynamic"
}

variable "subnet_id" {
  description = "(Required) The ID of the Subnet which should be used with the Network Interface."
  type        = string
}

variable "public_ip_address_id" {
  description = "(Optional) The ID of a Public IP Address to associate with the Network Interface."
  type        = string
  default     = null
}

variable "size" {
  description = "(Optional) The size of the Virtual Machine."
  type        = string
  default     = "Standard_B2s_v2"
}

variable "zone" {
  description = "(Optional) The Availability Zone which the Virtual Machine should be allocated in."
  type        = number
  default     = null
}

variable "admin_username" {
  description = "(Optional) The username of the local administrator to be created on the Virtual Machine."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "(Optional) The password of the local administrator to be created on the Virtual Machine. By default SSH keys are used."
  type        = string
  default     = ""
}

variable "ssh_algorithm" {
  description = "Algorithm to use when ssh is enabled."
  type        = string
  default     = "ED25519"
  validation {
    condition     = contains(["RSA", "ED25519", "ECDSA"], var.ssh_algorithm)
    error_message = "ssh_algorithm must be one of: 'RSA', 'ED25519', 'ECDSA'"
  }
}

variable "custom_os_disk_name" {
  description = "(Optional) The name of the OS Disk."
  type        = string
  default     = ""
}

variable "os_disk_caching" {
  description = "(Optional) The Type of Caching which should be used for the Virtual Machine's OS Disk."
  type        = string
  default     = "ReadWrite"
}

variable "os_disk_type" {
  description = "(Optional) The type of OS Disk which should be attached to the Virtual Machine."
  type        = string
  default     = "StandardSSD_LRS"
}

variable "os_disk_size" {
  description = "(Optional) The size of the OS Disk which should be attached to the Virtual Machine."
  type        = number
  default     = 30
}

variable "source_image_reference_publisher" {
  description = "(Optional) The publisher of the image which should be used for the Virtual Machine."
  type        = string
  default     = "Canonical"
}

variable "source_image_reference_offer" {
  description = "(Optional) The offer of the image which should be used for the Virtual Machine."
  type        = string
  default     = "ubuntu-24_04-lts"
}

variable "source_image_reference_sku" {
  description = "(Optional) The SKU of the image which should be used for the Virtual Machine."
  type        = string
  default     = "server"
}

variable "source_image_reference_version" {
  description = "(Optional) The version of the image which should be used for the Virtual Machine."
  type        = string
  default     = "latest"
}

variable "plan_name" {
  description = "(Optional) Vendor market place plan."
  type        = string
  default     = ""
}

variable "plan_product" {
  description = "(Optional) Vendor market place product"
  type        = string
  default     = ""
}

variable "plan_publisher" {
  description = "(Optional) Vendor market place publisher"
  type        = string
  default     = ""
}

variable "patch_mode" {
  description = "(Optional) The patching configuration of the Virtual Machine."
  type        = string
  default     = null
}

variable "patch_assessment_mode" {
  description = "(Optional) The patching configuration of the Virtual Machine."
  type        = string
  default     = null
}

variable "identity_type" {
  description = "(Optional) The type of Managed Service Identity which should be used for the Virtual Machine."
  type        = string
  default     = "None"
}

variable "identity_ids" {
  description = "(Optional) A list of Managed Service Identity IDs which should be assigned to the Virtual Machine."
  type        = list(string)
  default     = []
}

variable "priority" {
  description = "(Optional) The priority of the Virtual Machine."
  type        = string
  default     = "Regular"
}

variable "eviction_policy" {
  description = "(Optional) The eviction policy of the Virtual Machine."
  type        = string
  default     = "Deallocate"
}

variable "max_bid_price" {
  description = "(Optional) The maximum bid price for the Virtual Machine."
  type        = number
  default     = -1
}

variable "run_bootstrap" {
  description = "(Optional) Run the bootstrap script?"
  type        = bool
  default     = true
}

variable "custom_data" {
  description = "(Optional) The Base64 encoded Custom Data which should be used for the Virtual Machine."
  type        = string
  default     = null
}

variable "monitor_agent" {
  description = "(Optional) Install the Azure Monitor Agent?"
  type        = bool
  default     = false
}

variable "monitor_agent_publisher" {
  description = "(Optional) The name of the extension publisher."
  type        = string
  default     = "Microsoft.Azure.Monitor"
}

variable "monitor_agent_type" {
  description = "(Optional) The type of the extension."
  type        = string
  default     = "AzureMonitorLinuxAgent"
}

variable "monitor_agent_type_handler_version" {
  description = "(Optional) Specifies the version of the script handler."
  type        = string
  default     = "1.39"
}

variable "monitor_agent_automatic_upgrade_enabled" {
  description = "(Optional) Should the extension be automatically upgraded when a new version is published?"
  type        = bool
  default     = true
}

variable "monitor_agent_auto_upgrade_minor_version" {
  description = "(Optional) Should the extension be automatically upgraded across minor versions when Azure updates the extension?"
  type        = bool
  default     = true
}

variable "dependency_agent" {
  description = "(Optional) Install the Dependency Agent? Note: Not supported on Ubuntu 24.04."
  type        = bool
  default     = false
}

variable "dependency_agent_publisher" {
  description = "(Optional) The name of the extension publisher."
  type        = string
  default     = "Microsoft.Azure.Monitoring.DependencyAgent"
}

variable "dependency_agent_type" {
  description = "(Optional) The type of the extension."
  type        = string
  default     = "DependencyAgentLinux"
}

variable "dependency_agent_type_handler_version" {
  description = "(Optional) Specifies the version of the script handler."
  type        = string
  default     = "9.5"
}

variable "dependency_agent_automatic_upgrade_enabled" {
  description = "(Optional) Should the extension be automatically upgraded when a new version is published?"
  type        = bool
  default     = true
}

variable "dependency_agent_auto_upgrade_minor_version" {
  description = "(Optional) Should the extension be automatically upgraded across minor versions when Azure updates the extension?"
  type        = bool
  default     = true
}

variable "watcher_agent" {
  description = "(Optional) Install the Azure Monitor Agent?"
  type        = bool
  default     = false
}

variable "watcher_agent_publisher" {
  description = "(Optional) The name of the extension publisher."
  type        = string
  default     = "Microsoft.Azure.NetworkWatcher"
}

variable "watcher_agent_type" {
  description = "(Optional) The type of the extension."
  type        = string
  default     = "NetworkWatcherAgentLinux"
}

variable "watcher_agent_type_handler_version" {
  description = "(Optional) Specifies the version of the script handler."
  type        = string
  default     = "1.4"
}

variable "watcher_agent_automatic_upgrade_enabled" {
  description = "(Optional) Should the extension be automatically upgraded when a new version is published?"
  type        = bool
  default     = true
}

variable "watcher_agent_auto_upgrade_minor_version" {
  description = "(Optional) Should the extension be automatically upgraded across minor versions when Azure updates the extension?"
  type        = bool
  default     = true
}

variable "agents" {
  description = "(Optional) A map of agents to install."
  type = map(object({
    publisher                  = string
    type                       = string
    type_handler_version       = string
    automatic_upgrade_enabled  = bool
    auto_upgrade_minor_version = bool
    settings                   = string
  }))
  default = {}
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}

variable "random_string" {
  description = "(Optional) A random string suffix to ensure all resources in a deployment share the same identifier."
  type        = string
  default     = ""
}