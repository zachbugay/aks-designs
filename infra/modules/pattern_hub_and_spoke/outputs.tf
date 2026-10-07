output "azure_monitor_workspace_id" {
  description = "The ID of the Log Azure Monitor Workspace."
  value       = module.hub.azure_monitor_workspace_id
}

output "firewall_private_ip" {
  description = "The ID of the Firewall."
  value       = var.firewall.enabled ? module.hub.firewall_private_ip : null
}

output "hub_private_endpoint_subnet_id" {
  value = module.hub.private_endpoint_subnet_id
}

output "hub_resource_group_name" {
  description = "The name of the resource group of the spoke."
  value       = module.hub.resource_group_name
}

output "hub_virtual_network_id" {
  value = module.hub.virtual_network_id
}

output "key_vault_name" {
  description = "The name of the Key Vault."
  value       = try(module.private_key_vault[0].name, null)
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace."
  value       = module.hub.log_analytics_workspace_id
}

output "private_dns_zones" {
  description = "Set of private DNS zones configured in the DNS spoke."
  value       = try(module.spoke_dns[0].private_dns_zones, null)
}

output "virtual_network_gateway_id" {
  description = "The ID of the Gateway."
  value       = var.virtual_network_gateway ? module.hub.virtual_network_gateway_id : null
}

output "virtual_network_gateway_public_ip_address" {
  description = "The public IP address of the Gateway."
  value       = var.virtual_network_gateway ? module.hub.virtual_network_gateway_public_ip_address : null
}

output "dns_servers" {
  value = local.dns_servers
}

output "virtual_network_gateway_route_table_name" {
  value = module.hub.virtual_network_gateway_route_table_name
}
