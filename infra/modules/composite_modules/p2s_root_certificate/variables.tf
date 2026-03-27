variable "environment" {
  description = "(Required) The environment of the Point-to-Site root certificate."
  type        = string
}

variable "workload" {
  description = "(Required) The usage or application of the Point-to-Site root certificate."
  type        = string
}

variable "custom_name" {
  description = "(Optional) Custom name for the Point-to-Site root certificate."
  type        = string
  default     = ""
}

variable "instance" {
  description = "(Optional) The instance count for the Point-to-Site root certificate."
  type        = string
  default     = "001"
}

variable "key_vault_id" {
  description = "(Required) The ID of the Key Vault in which to store the root certificate and its private key."
  type        = string
}

variable "validity_period_hours" {
  description = "(Optional) The number of hours the root certificate remains valid for. Defaults to 5 years."
  type        = number
  default     = 43800
}

variable "early_renewal_hours" {
  description = "(Optional) The number of hours before expiry at which the root certificate is regenerated. Defaults to 30 days."
  type        = number
  default     = 720
}

variable "tags" {
  description = "(Optional) A mapping of tags to assign to the resource."
  type        = map(string)
  default     = {}
}
