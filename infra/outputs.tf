output "HUB_RESOURCE_GROUP" {
  description = "Resource group name of the hub."
  value       = module.pattern_hub_and_spoke.hub_resource_group_name
}

output "ACR_ID" {
  description = "The Container Registry ID this cluster has AcrPull access to."
  value       = module.pattern_hub_and_spoke.acr_id
}

output "ACR_NAME" {
  description = "The Container Registry name this cluster has AcrPull access to."
  value       = module.pattern_hub_and_spoke.acr_name
}

output "AZURE_CONTAINER_REGISTRY_ENDPOINT" {
  description = "The Container Registry Endpoint."
  value       = module.pattern_hub_and_spoke.acr_endpoint
}

output "AKS_LB_SNET_ID" {
  description = "Delegated subnet for the Application Gateway for Containers."
  value = module.pattern_hub_and_spoke.aks_lb_snet_id
}

output "AZURE_AKS_CLUSTER_NAME" {
  description = "The name of the AKS cluster (azd convention)."
  value       = module.pattern_hub_and_spoke.AZURE_AKS_CLUSTER_NAME
}

output "AKS_RESOURCE_GROUP" {
  description = "The name of the AKS resource group."
  value       = module.pattern_hub_and_spoke.aks_resource_group_name
}

output "LOG_ANALYTICS_WORKSPACE_ID" {
  description = "The ID of the Log Analytics Workspace."
  value       = module.pattern_hub_and_spoke.log_analytics_workspace_id
}

output "KEY_VAULT_NAME" {
  description = "The name of the Key Vault."
  value       = module.pattern_hub_and_spoke.key_vault_name
}

output "KUBELET_IDENTITY_CLIENT_ID" {
  description = "The client ID of the kubelet managed identity."
  value       = module.pattern_hub_and_spoke.kubelet_identity_client_id
}
