output "resource_group_name" {
  description = "The name of the resource group of the hub."
  value       = module.resource_group.name
}

output "resource_group_management_name" {
  description = "The name of the management resource group."
  value       = module.resource_group_management.name
}

output "virtual_network_name" {
  description = "The name of the virtual network of the hub."
  value       = module.virtual_network.name
}

output "virtual_network_id" {
  description = "The ID of the virtual network of the hub."
  value       = module.virtual_network.id
}

output "gateway_public_ip_address" {
  description = "The public IP address of the Gateway."
  value       = var.gateway ? module.public_ip_gateway[*].ip_address : null
}

output "gateway_id" {
  description = "The ID of the Gateway."
  value       = var.gateway ? module.virtual_network_gateway[0].id : null
}

output "gateway_route_table_name" {
  description = "The name of the Route Table for the Virtual Network Gateway."
  value       = module.route_table_gateway.name
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace."
  value       = module.log_analytics_workspace.id
}

output "log_analytics_workspace_workspace_id" {
  description = "The resource ID of the Log Analytics Workspace."
  value       = module.log_analytics_workspace.workspace_id
}

output "firewall_private_ip" {
  description = "Private IP of the Firewall"
  value       = var.firewall ? module.firewall[0].private_ip_address : null
}

output "firewall_public_ip_address" {
  description = "Public IP Address of the Firewall."
  value       = var.firewall ? module.public_ip_firewall[0].ip_address : null
}

output "application_gateway_public_ip_address" {
  description = "Public IP Address of the Application Gateway."
  value       = var.application_gateway ? module.public_ip_appgw[0].ip_address : null
}

output "nat_gateway_id" {
  description = "Resource ID of the NAT Gateway."
  value       = module.nat_gateway[0].id
}

output "nat_gateway_name" {
  description = "Resource ID of the NAT Gateway."
  value       = module.nat_gateway[0].name
}

output "nat_gateway_public_ip_addresses" {
  description = "The public IP addresses of the NAT Gateway."
  value       = [for pip in module.public_ip_nat_gateway : pip.ip_address]
}

output "storage_account_id" {
  description = "The ID of the Storage Account."
  value       = var.storage_account ? module.storage_account[0].id : null
}

output "azure_monitor_workspace_id" {
  description = "The ID of the Azure Monitor Workspace."
  value       = module.monitor_workspace.id
}

output "azure_monitor_workspace_name" {
  description = "The name of the Azure Monitor Workspace."
  value       = module.monitor_workspace.name
}

output "azure_monitor_workspace_default_data_collection_endpoint_id" {
  description = "The ID of the default Data Collection Endpoint associated with the Azure Monitor Workspace."
  value       = module.monitor_workspace.default_data_collection_endpoint_id
}

output "azure_monitor_workspace_default_data_collection_rule_id" {
  description = "The ID of the default Data Collection Rule associated with the Azure Monitor Workspace."
  value       = module.monitor_workspace.default_data_collection_rule_id
}

output "azure_monitor_workspace_query_endpoint" {
  description = "The query endpoint for the Azure Monitor Workspace."
  value       = module.monitor_workspace.query_endpoint
}
