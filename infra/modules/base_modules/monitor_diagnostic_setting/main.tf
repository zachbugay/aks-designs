resource "azurecaf_name" "this" {
  resource_type = "azurerm_monitor_diagnostic_setting"
  clean_input = true
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = coalesce(var.custom_name, azurecaf_name.this.result)
  target_resource_id         = var.target_resource_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
