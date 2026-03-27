locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "load_balancer"
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )
  instance = coalesce(var.instance, "001")
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurecaf_name" "this" {
  name          = var.workload
  resource_type = "azurerm_lb"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurerm_lb" "this" {
  name                = coalesce(var.custom_name, azurecaf_name.this.result)
  location            = module.locations.name
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  frontend_ip_configuration {
    name                 = var.frontend_name
    public_ip_address_id = var.public_ip_address_id
  }

  tags = local.tags
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = var.backend_pool_name
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "this" {
  name                = var.probe_name
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = var.probe_protocol
  port                = var.probe_port
  interval_in_seconds = var.probe_interval
  number_of_probes    = var.probe_number_of_probes
}

resource "azurerm_lb_rule" "this" {
  for_each                       = var.lb_rules
  name                           = each.key
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = title(each.value.protocol)
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_ip_configuration_name = var.frontend_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.this.id
  floating_ip_enabled            = false
  idle_timeout_in_minutes        = 4
  disable_outbound_snat          = var.disable_outbound_snat
}
