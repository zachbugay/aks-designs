locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "route_table"
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

resource "azurecaf_name" "this" {
  name          = var.workload
  resource_type = "azurerm_route_table"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurerm_route_table" "this" {
  name                          = coalesce(var.custom_name, azurecaf_name.this.result)
  location                      = module.locations.name
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = var.bgp_route_propagation_enabled
  tags                          = local.tags
}
