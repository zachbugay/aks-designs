output "id" {
  description = "The ID of the Azure Monitor Workspace."
  value       = azurerm_monitor_workspace.this.id
}

output "name" {
  description = "The name of the Azure Monitor Workspace."
  value       = azurerm_monitor_workspace.this.name
}

output "default_data_collection_endpoint_id" {
  description = "The ID of the default Data Collection Endpoint associated with the Azure Monitor Workspace."
  value       = azurerm_monitor_workspace.this.default_data_collection_endpoint_id
}

output "default_data_collection_rule_id" {
  description = "The ID of the default Data Collection Rule associated with the Azure Monitor Workspace."
  value       = azurerm_monitor_workspace.this.default_data_collection_rule_id
}

output "query_endpoint" {
  description = "The query endpoint for the Azure Monitor Workspace."
  value       = azurerm_monitor_workspace.this.query_endpoint
}
