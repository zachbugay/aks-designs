variable "region_names" {
  description = "List of regions to query VM SKU availability zones for"
  type        = list(string)
  default     = ["westus3"]
}

variable "vm_skus" {
  description = "List of VM SKUs to check availability zone support for"
  type        = list(string)
  default     = ["Standard_D2s_v3"]
}
