variable "custom_name" {
  description = "(Optional) Custom name for the Application Gateway."
  type        = string
  default     = ""
}

variable "workload" {
  description = "(Optional) The usage or application of the Application Gateway."
  type        = string
  default     = ""
}

variable "environment" {
  description = "(Required) The environment of the Application Gateway."
  type        = string
}

variable "location" {
  description = "(Required) The location/region where the Application Gateway is created."
  type        = string
}

variable "resource_group_name" {
  description = "(Required) The name of the resource group."
  type        = string
}

variable "instance" {
  description = "(Optional) The instance count."
  type        = string
  default     = ""
}

variable "sku" {
  description = "(Optional) The SKU of the Application Gateway. Accepted values are Basic, Standard_v2, and WAF_v2."
  type        = string
  default     = "Standard_v2"

  validation {
    condition     = contains(["Basic", "Standard_v2", "WAF_v2"], var.sku)
    error_message = "SKU must contain one of: 'Basic', 'Standard_v2', 'WAF_v2'"
  }
}

variable "sku_capacity" {
  description = "(Optional) The capacity (instance count) of the Application Gateway."
  type        = number
  default     = 1

  validation {
    condition     = var.sku_capacity <= 125
    error_message = "SKU Capacity must be <= 125 for v2."
  }
}

variable "zones" {
  description = "(Optional) The availability zones the Application Gateway is spread across. Must match the zones of the frontend Public IP."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "subnet_id" {
  description = "(Required) The ID of the subnet for the Application Gateway."
  type        = string
}

variable "frontend_ip_name" {
  description = "(Required) The name of the front end IP."
  type        = string
}

variable "public_ip_address_id" {
  description = "(Required) The ID of the public IP for the frontend."
  type        = string
}

variable "backend_ip_addresses" {
  description = "(Optional) List of backend IP addresses (e.g., Istio internal LB IP)."
  type        = list(string)
  default     = []
}

variable "backend_fqdns" {
  description = "(Optional) List of backend FQDNs."
  type        = list(string)
  default     = []
}

variable "waf_enabled" {
  description = "(Optional) Enable WAF on the Application Gateway. Only supported on WAF_v2 SKU."
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "(Optional) The WAF mode. Accepted values are Detection and Prevention."
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode must be either 'Detection', or 'Prevention'"
  }
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

variable "admin_object_ids" {
  description = "(Optional) List of Microsoft Entra group object IDs that will have admin role of the cluster."
  type        = set(string)
  default     = []
}

variable "identity_id" {
  description = "(Required) The ID of the User Assigned Managed Identity the Application Gateway uses to read its certificate from Key Vault."
  type        = string
}

variable "ssl_certificate_key_vault_secret_id" {
  description = "(Required) The versionless Key Vault secret ID of the frontend TLS certificate."
  type        = string
}

variable "trusted_root_certificate_pem" {
  description = "(Optional) PEM encoded root certificate that signs the backend TLS certificates. When null, the backend HTTP settings rely on the default trusted certificate authorities."
  type        = string
  default     = null
}

variable "appgw_applications" {
  description = <<-EOT
    Applications published through the Application Gateway. Each entry generates a health probe,
    backend HTTP settings, an HTTPS listener, an HTTP listener, an HTTPS routing rule, and an
    HTTP-to-HTTPS redirect. The map key is the application name and is used to build resource names.

    `rule_type` applies to the application's HTTPS routing rule. When it is `PathBasedRouting`,
    `path_rules` must be populated and a URL path map is generated for the application; unmatched
    paths fall through to the application's own backend HTTP settings. Each path rule may target a
    different application's backend HTTP settings via `backend_app`. The HTTP-to-HTTPS redirect rule
    is always `Basic`, since it redirects every path to the HTTPS listener.

    `https_port` and `http_port` are gateway wide: the Application Gateway exposes a single shared
    `https-port` and `http-port` frontend port, so every application must declare the same values.
  EOT

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

  validation {
    condition     = length(var.appgw_applications) > 0
    error_message = "At least one application must be defined in appgw_applications."
  }

  validation {
    condition = alltrue(flatten([
      for app in var.appgw_applications : [
        for port in [app.https_port, app.http_port] : port >= 1 && port <= 65535
      ]
    ]))
    error_message = "Frontend ports must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for app in var.appgw_applications : app.https_port != app.http_port
    ])
    error_message = "The HTTPS and HTTP frontend ports must be different."
  }

  validation {
    condition = length(distinct([
      for app in var.appgw_applications : [app.https_port, app.http_port]
    ])) <= 1
    error_message = "The Application Gateway exposes one shared frontend port pair, so every application must declare the same https_port and http_port."
  }

  validation {
    condition = alltrue([
      for app in var.appgw_applications : contains(["Basic", "PathBasedRouting"], app.rule_type)
    ])
    error_message = "rule_type must be one of: Basic, PathBasedRouting."
  }

  validation {
    condition = alltrue([
      for app in var.appgw_applications :
      contains(["Permanent", "Temporary", "Found", "SeeOther"], app.redirect_type)
    ])
    error_message = "redirect_type must be one of: Permanent, Temporary, Found, SeeOther."
  }

  validation {
    condition = alltrue([
      for app in var.appgw_applications :
      length(app.path_rules) > 0 if app.rule_type == "PathBasedRouting"
    ])
    error_message = "Applications with rule_type PathBasedRouting must define at least one entry in path_rules."
  }

  validation {
    condition = alltrue([
      for app in var.appgw_applications :
      length(app.path_rules) == 0 if app.rule_type != "PathBasedRouting"
    ])
    error_message = "path_rules may only be set when rule_type is PathBasedRouting."
  }

  validation {
    condition = alltrue([
      for app in var.appgw_applications :
      length(distinct([for rule in app.path_rules : rule.name])) == length(app.path_rules)
    ])
    error_message = "Path rule names must be unique within an application."
  }

  validation {
    condition = alltrue(flatten([
      for app in var.appgw_applications : [
        for rule in app.path_rules : length(rule.paths) > 0 && alltrue([
          for path in rule.paths : startswith(path, "/")
        ])
      ]
    ]))
    error_message = "Every path rule must declare at least one path, and each path must start with \"/\"."
  }

  validation {
    condition = alltrue(flatten([
      for app in var.appgw_applications : [
        for rule in app.path_rules :
        contains(keys(var.appgw_applications), rule.backend_app) if rule.backend_app != null
      ]
    ]))
    error_message = "Each path rule backend_app must reference a key defined in appgw_applications."
  }

  validation {
    condition = length(distinct(flatten([
      for app in var.appgw_applications : [app.https_rule_priority, app.http_redirect_rule_priority]
    ]))) == length(var.appgw_applications) * 2
    error_message = "Every routing rule priority in appgw_applications must be unique."
  }

  validation {
    condition = alltrue(flatten([
      for app in var.appgw_applications : [
        for priority in [app.https_rule_priority, app.http_redirect_rule_priority] :
        priority >= 1 && priority <= 20000
      ]
    ]))
    error_message = "Routing rule priorities must be between 1 and 20000."
  }
}

