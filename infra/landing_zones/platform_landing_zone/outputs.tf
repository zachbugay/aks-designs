output "DNS_SERVERS" {
  value = module.pattern_hub_and_spoke.dns_servers
}

output "HUB_AZURE_MONITOR_WORKSPACE_ID" {
  description = "Resource ID for the hub azure monitor workspace."
  value       = module.pattern_hub_and_spoke.azure_monitor_workspace_id
}

output "HUB_FIREWALL_PRIVATE_IP" {
  value = module.pattern_hub_and_spoke.firewall_private_ip
}

output "HUB_KEY_VAULT_NAME" {
  description = "The name of the Key Vault."
  value       = module.pattern_hub_and_spoke.key_vault_name
}

output "HUB_LOG_ANALYTICS_WORKSPACE_ID" {
  description = "The ID of the Log Analytics Workspace."
  value       = module.pattern_hub_and_spoke.log_analytics_workspace_id
}

output "HUB_PRIVATE_ENDPOINT_SUBNET_ID" {
  value = module.pattern_hub_and_spoke.hub_private_endpoint_subnet_id
}

output "HUB_RESOURCE_GROUP_NAME" {
  description = "Resource group name of the hub."
  value       = module.pattern_hub_and_spoke.hub_resource_group_name
}

output "HUB_VIRTUAL_NETWORK_ID" {
  description = "Resource ID for the hub virtual network."
  value       = module.pattern_hub_and_spoke.hub_virtual_network_id
}

output "PRIVATE_DNS_ZONES" {
  value = module.pattern_hub_and_spoke.private_dns_zones
}

output "VIRTUAL_NETWORK_GATEWAY_ROUTE_TABLE_NAME" {
  value = module.pattern_hub_and_spoke.virtual_network_gateway_route_table_name
}

resource "local_file" "platform_landing_zone_outputs" {
  filename = "${path.root}/outputs/${local.environment}.outputs.generated.yaml"
  content = yamlencode({
    platform_landing_zone = {
      azure_monitor_workspace_id     = module.pattern_hub_and_spoke.azure_monitor_workspace_id
      dns_servers                    = module.pattern_hub_and_spoke.dns_servers
      hub_private_endpoint_subnet_id = module.pattern_hub_and_spoke.hub_private_endpoint_subnet_id
      hub_resource_group_name        = module.pattern_hub_and_spoke.hub_resource_group_name
      hub_virtual_network_id         = module.pattern_hub_and_spoke.hub_virtual_network_id
      location                       = var.location
      log_analytics_workspace_id     = module.pattern_hub_and_spoke.log_analytics_workspace_id
      private_dns_zones              = module.pattern_hub_and_spoke.private_dns_zones
      firewall = {
        enabled    = local.firewall.enabled
        private_ip = module.pattern_hub_and_spoke.firewall_private_ip
      }
      virtual_network_gateway = {
        enabled          = local.virtual_network_gateway.enabled
        route_table_name = module.pattern_hub_and_spoke.virtual_network_gateway_route_table_name
      }
    }
  })
}
