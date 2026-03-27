locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "container_registry",
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
  resource_type = "azurerm_container_registry"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

module "acr" {
  source                  = "Azure/avm-res-containerregistry-registry/azurerm"
  version                 = "0.5.1"
  name                    = coalesce(var.custom_name, azurecaf_name.this.result)
  resource_group_name     = var.resource_group_name
  location                = module.locations.name
  sku                     = var.sku
  tags                    = var.tags
  zone_redundancy_enabled = false
}