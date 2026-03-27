module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.11.0"

  region_filter   = var.region_names
  use_cached_data = false
}

data "azurerm_subscription" "current" {}

data "azapi_resource_list" "compute_skus" {
  for_each  = toset(var.region_names)
  type      = "Microsoft.Compute/skus@2021-07-01"
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"

  query_parameters = {
    "$filter" = ["location eq '${each.value}'"]
  }

  response_export_values = {
    skus = "value[?resourceType == 'virtualMachines'].{name: name, zones: locationInfo[0].zones}"
  }
}

locals {
  vm_sku_zones = {
    for sku in var.vm_skus : sku => {
      for region in var.region_names : region => try(
        one([for s in data.azapi_resource_list.compute_skus[region].output.skus : s.zones if s.name == sku]),
        []
      )
    }
  }
}
