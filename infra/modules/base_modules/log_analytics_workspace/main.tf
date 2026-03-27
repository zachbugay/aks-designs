locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "log_analytics_workspace"
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
  resource_type = "azurerm_log_analytics_workspace"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurerm_log_analytics_workspace" "this" {
  name                            = coalesce(var.custom_name, azurecaf_name.this.result)
  location                        = module.locations.name
  resource_group_name             = var.resource_group_name
  sku                             = var.sku
  retention_in_days               = var.retention_in_days
  allow_resource_only_permissions = var.allow_resource_only_permissions
  local_authentication_enabled    = var.local_authentication_enabled
  daily_quota_gb                  = var.daily_quota_gb
  internet_ingestion_enabled      = var.internet_ingestion_enabled
  internet_query_enabled          = var.internet_query_enabled
  tags                            = local.tags
}
