variable "custom_name" {
  description = "(Optional) The name of the Route Table."
  type        = string
  default     = ""
}

variable "workload" {
  description = "(Optional) The usage or application of the Route Table."
  type        = string
  default     = ""
}

variable "environment" {
  description = "(Optional) The environment of the Route Table."
  type        = string
  default     = ""
}

variable "location" {
  description = "(Required) The location/region where the Route Table is created. Changing this forces a new resource to be created."
  type        = string
}

variable "instance" {
  description = "(Optional) The instance count for the Route Table."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group in which to create the Route Table."
  type        = string
}

variable "next_hop" {
  description = "(Optional) The IP address packets should be forwarded to when they don't match any of the routes in the route table."
  type        = string
  default     = null
}

variable "next_hop_type" {
  description = "(Required) The type of Azure hop the packet should be sent to. Possible values are VirtualNetworkGateway, VnetLocal, Internet, VirtualAppliance and None"
  type        = string
}

variable "subnet_id" {
  description = "(Required) The ID of the Subnet which should be associated with this Route Table."
  type        = string
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