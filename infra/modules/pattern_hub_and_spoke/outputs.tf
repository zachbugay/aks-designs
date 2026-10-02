output "hub_resource_group_name" {
  description = "The name of the resource group of the spoke."
  value       = module.hub.resource_group_name
}

output "key_vault_name" {
  description = "The name of the Key Vault."
  value       = try(module.private_key_vault[0].name, null)
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace to log Application Gateway."
  value       = module.hub.log_analytics_workspace_id
}

output "virtual_network_gateway_public_ip_address" {
  description = "The public IP address of the Gateway."
  value       = var.virtual_network_gateway ? module.hub.virtual_network_gateway_public_ip_address : null
}

output "virtual_network_gateway_id" {
  description = "The ID of the Gateway."
  value       = var.virtual_network_gateway ? module.hub.virtual_network_gateway_id : null
}
