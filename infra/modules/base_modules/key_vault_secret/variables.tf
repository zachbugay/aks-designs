variable "name" {
  description = "(Required) The name of the Key Vault Secret."
  type        = string
}

variable "value" {
  description = "(Required) The value of the Key Vault Secret."
  type        = string
}

variable "key_vault_id" {
  description = "(Required) The ID of the Key Vault Secret."
  type        = string
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = null
}