locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "nat_gateway"
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

resource "azurerm_nat_gateway" "this" {
  resource_group_name     = var.resource_group_name
  location                = module.locations.name
  name                    = "${var.environment}-ng-${var.random_string}-${local.instance}"
  sku_name                = var.sku
  zones                   = var.zones
  idle_timeout_in_minutes = var.idle_timeout_in_minutes
}
