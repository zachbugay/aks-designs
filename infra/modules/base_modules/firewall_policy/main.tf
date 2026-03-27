locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "firewall_workbook"
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
  resource_type = "azurerm_firewall_policy"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_firewall_policy" "this" {
  name                              = coalesce(var.custom_name, azurecaf_name.this.result)
  location                          = module.locations.name
  resource_group_name               = var.resource_group_name
  base_policy_id                    = var.base_policy_id
  private_ip_ranges                 = var.private_ip_ranges
  auto_learn_private_ranges_enabled = var.auto_learn_private_ranges_enabled
  sku                               = var.sku
  threat_intelligence_mode          = var.threat_intelligence_mode
  sql_redirect_allowed              = var.sql_redirect_allowed

  dynamic "dns" {
    for_each = var.sku != "Basic" ? [1] : []
    content {
      proxy_enabled = var.dns_proxy_enabled
      servers       = var.dns_servers
    }
  }

  tags = local.tags
}