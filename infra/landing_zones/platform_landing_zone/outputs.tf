output "HUB_RESOURCE_GROUP" {
  description = "Resource group name of the hub."
  value       = module.pattern_hub_and_spoke.hub_resource_group_name
}

output "LOG_ANALYTICS_WORKSPACE_ID" {
  description = "The ID of the Log Analytics Workspace."
  value       = module.pattern_hub_and_spoke.log_analytics_workspace_id
}

output "KEY_VAULT_NAME" {
  description = "The name of the Key Vault."
  value       = module.pattern_hub_and_spoke.key_vault_name
}

