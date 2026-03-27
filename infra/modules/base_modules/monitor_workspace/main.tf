locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "monitor_workspace"
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

resource "azurerm_monitor_workspace" "this" {
  name                          = coalesce(var.custom_name, "${var.environment}-mamw-mon-${var.random_string}-${local.instance}")
  resource_group_name           = var.resource_group_name
  location                      = module.locations.name
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = local.tags
}
