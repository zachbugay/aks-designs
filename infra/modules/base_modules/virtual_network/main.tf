locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "virtual_network"
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
  resource_type = "azurerm_virtual_network"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurerm_virtual_network" "this" {
  name                = coalesce(var.custom_name, azurecaf_name.this.result)
  location            = module.locations.name
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = local.tags
}
