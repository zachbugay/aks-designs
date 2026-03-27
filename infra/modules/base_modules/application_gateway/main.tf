locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "application_gateway"
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )

  instance = coalesce(var.instance, "001")

  # Names of the Application Gateway child resources. These are internal to the gateway and are
  # only referenced by the blocks below, so they are not exposed as variables.
  agw_ssl_certificate_name          = "app-frontend"
  agw_trusted_root_certificate_name = "backend-root-cert"
  agw_backend_address_pool_name     = "istio-gateway-pool"
  agw_https_port_name               = "https-port"
  agw_http_port_name                = "http-port"

  agw_trusted_root_certificate_names = var.trusted_root_certificate_pem != null ? [local.agw_trusted_root_certificate_name] : null

  frontend_ip_configuration_name = "${var.frontend_ip_name}-feip"

  # Every application shares the same frontend port pair, enforced by variable validation.
  agw_frontend_ports = {
    (local.agw_https_port_name) = one(distinct([for app in var.appgw_applications : app.https_port]))
    (local.agw_http_port_name)  = one(distinct([for app in var.appgw_applications : app.http_port]))
  }

  # Resolved application definitions with the derived Application Gateway child resource names.
  agw_applications = {
    for key, app in var.appgw_applications : key => merge(app, {
      hostname                    = app.hostname
      probe_name                  = "istio-${key}-probe"
      backend_http_settings_name  = "${key}-http-setting"
      https_listener_name         = "${key}-https-listener"
      http_listener_name          = "${key}-http-listener"
      https_rule_name             = "${key}-https-rule"
      redirect_configuration_name = "${key}-http-redirect"
      http_redirect_rule_name     = "${key}-http-redirect-rule"
      url_path_map_name           = app.rule_type == "PathBasedRouting" ? "${key}-path-map" : null
    })
  }

  # URL path maps are only generated for applications using path based routing.
  agw_url_path_maps = {
    for key, app in local.agw_applications : app.url_path_map_name => {
      default_backend_address_pool_name  = local.agw_backend_address_pool_name
      default_backend_http_settings_name = app.backend_http_settings_name
      path_rules = [
        for rule in app.path_rules : {
          name                       = rule.name
          paths                      = rule.paths
          backend_address_pool_name  = local.agw_backend_address_pool_name
          backend_http_settings_name = local.agw_applications[coalesce(rule.backend_app, key)].backend_http_settings_name
        }
      ]
    } if app.rule_type == "PathBasedRouting"
  }

  agw_http_listeners = merge(
    {
      for key, app in local.agw_applications : app.https_listener_name => {
        host_name            = app.hostname
        frontend_port_name   = local.agw_https_port_name
        protocol             = "Https"
        ssl_certificate_name = local.agw_ssl_certificate_name
      }
    },
    {
      for key, app in local.agw_applications : app.http_listener_name => {
        host_name            = app.hostname
        frontend_port_name   = local.agw_http_port_name
        protocol             = "Http"
        ssl_certificate_name = null
      }
    }
  )

  agw_request_routing_rules = merge(
    {
      for key, app in local.agw_applications : app.https_rule_name => {
        rule_type                   = app.rule_type
        priority                    = app.https_rule_priority
        http_listener_name          = app.https_listener_name
        backend_address_pool_name   = app.rule_type == "PathBasedRouting" ? null : local.agw_backend_address_pool_name
        backend_http_settings_name  = app.rule_type == "PathBasedRouting" ? null : app.backend_http_settings_name
        redirect_configuration_name = null
        url_path_map_name           = app.url_path_map_name
      }
    },
    {
      # The HTTP listener redirects every path to HTTPS, so this rule is always Basic.
      for key, app in local.agw_applications : app.http_redirect_rule_name => {
        rule_type                   = "Basic"
        priority                    = app.http_redirect_rule_priority
        http_listener_name          = app.http_listener_name
        backend_address_pool_name   = null
        backend_http_settings_name  = null
        redirect_configuration_name = app.redirect_configuration_name
        url_path_map_name           = null
      }
    }
  )
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurecaf_name" "this" {
  name          = var.workload
  resource_type = "azurerm_application_gateway"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}



resource "azurerm_application_gateway" "this" {
  name                = coalesce(var.custom_name, azurecaf_name.this.result)
  resource_group_name = var.resource_group_name
  location            = module.locations.name
  tags                = local.tags
  zones               = var.zones

  sku {
    name     = var.sku
    tier     = var.sku
    capacity = var.sku_capacity
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  gateway_ip_configuration {
    name      = "agw-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = var.public_ip_address_id
  }

  ssl_certificate {
    name                = local.agw_ssl_certificate_name
    key_vault_secret_id = var.ssl_certificate_key_vault_secret_id
  }

  dynamic "trusted_root_certificate" {
    for_each = var.trusted_root_certificate_pem != null ? [var.trusted_root_certificate_pem] : []

    content {
      name = local.agw_trusted_root_certificate_name
      data = base64encode(trusted_root_certificate.value)
    }
  }

  backend_address_pool {
    name         = local.agw_backend_address_pool_name
    ip_addresses = var.backend_ip_addresses
    fqdns        = var.backend_fqdns
  }

  dynamic "frontend_port" {
    for_each = local.agw_frontend_ports

    content {
      name = frontend_port.key
      port = frontend_port.value
    }
  }

  dynamic "probe" {
    for_each = local.agw_applications

    content {
      name                = probe.value.probe_name
      protocol            = probe.value.probe_protocol
      host                = probe.value.hostname
      path                = probe.value.probe_path
      interval            = probe.value.probe_interval
      timeout             = probe.value.probe_timeout
      unhealthy_threshold = probe.value.probe_unhealthy_threshold

      match {
        status_code = probe.value.probe_status_codes
      }
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.agw_applications

    content {
      name                                = backend_http_settings.value.backend_http_settings_name
      cookie_based_affinity               = backend_http_settings.value.cookie_based_affinity
      port                                = backend_http_settings.value.backend_port
      protocol                            = backend_http_settings.value.backend_protocol
      request_timeout                     = backend_http_settings.value.backend_request_timeout
      pick_host_name_from_backend_address = false
      host_name                           = backend_http_settings.value.hostname
      probe_name                          = backend_http_settings.value.probe_name
      trusted_root_certificate_names      = local.agw_trusted_root_certificate_names
    }
  }

  dynamic "http_listener" {
    for_each = local.agw_http_listeners

    content {
      name                           = http_listener.key
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = http_listener.value.frontend_port_name
      protocol                       = http_listener.value.protocol
      host_name                      = http_listener.value.host_name
      ssl_certificate_name           = http_listener.value.ssl_certificate_name
    }
  }

  dynamic "redirect_configuration" {
    for_each = local.agw_applications

    content {
      name                 = redirect_configuration.value.redirect_configuration_name
      redirect_type        = redirect_configuration.value.redirect_type
      target_listener_name = redirect_configuration.value.https_listener_name
      include_path         = true
      include_query_string = true
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.agw_request_routing_rules

    content {
      name                        = request_routing_rule.key
      priority                    = request_routing_rule.value.priority
      rule_type                   = request_routing_rule.value.rule_type
      http_listener_name          = request_routing_rule.value.http_listener_name
      backend_address_pool_name   = request_routing_rule.value.backend_address_pool_name
      backend_http_settings_name  = request_routing_rule.value.backend_http_settings_name
      redirect_configuration_name = request_routing_rule.value.redirect_configuration_name
      url_path_map_name           = request_routing_rule.value.url_path_map_name
    }
  }

  dynamic "url_path_map" {
    for_each = local.agw_url_path_maps

    content {
      name                               = url_path_map.key
      default_backend_address_pool_name  = url_path_map.value.default_backend_address_pool_name
      default_backend_http_settings_name = url_path_map.value.default_backend_http_settings_name

      dynamic "path_rule" {
        for_each = url_path_map.value.path_rules

        content {
          name                       = path_rule.value.name
          paths                      = path_rule.value.paths
          backend_address_pool_name  = path_rule.value.backend_address_pool_name
          backend_http_settings_name = path_rule.value.backend_http_settings_name
        }
      }
    }
  }

  dynamic "waf_configuration" {
    for_each = var.waf_enabled ? [1] : []

    content {
      enabled          = true
      firewall_mode    = var.waf_mode
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"
    }
  }

  lifecycle {
    ignore_changes = [backend_address_pool]

    precondition {
      condition     = alltrue([for key, app in local.agw_applications : app.hostname != ""])
      error_message = "Every entry in appgw_applications must set `hostname`."
    }

    precondition {
      condition     = !var.waf_enabled || var.sku == "WAF_v2"
      error_message = "waf_enabled requires the WAF_v2 SKU."
    }
  }
}
