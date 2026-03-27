locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "firewall"
    }
  )

  tags = merge(
    local.module_tags,
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
  resource_type = "azurerm_firewall"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_firewall" "this" {
  name                = coalesce(var.custom_name, azurecaf_name.this.result)
  location            = module.locations.name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  sku_tier            = var.sku_tier
  firewall_policy_id  = var.firewall_policy_id
  dns_servers         = var.sku_tier != "Basic" ? var.dns_servers : null
  private_ip_ranges   = var.private_ip_ranges
  threat_intel_mode   = var.sku_tier != "Basic" ? var.threat_intel_mode : "Off"
  zones               = var.zones

  ip_configuration {
    name                 = var.ip_configuration_name
    subnet_id            = var.subnet_id
    public_ip_address_id = var.public_ip_address_id
  }

  dynamic "management_ip_configuration" {
    for_each = var.management_ip_configuration != null ? [var.management_ip_configuration] : []
    content {
      name                 = management_ip_configuration.value.name
      subnet_id            = management_ip_configuration.value.subnet_id
      public_ip_address_id = management_ip_configuration.value.public_ip_address_id
    }
  }

  tags = local.tags
}
