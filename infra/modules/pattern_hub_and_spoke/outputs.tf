output "hub_resource_group_name" {
  description = "The name of the resource group of the spoke."
  value       = module.hub.resource_group_name
}

output "gateway_public_ip_address" {
  description = "The public IP address of the Gateway."
  value       = var.gateway ? module.hub.gateway_public_ip_address : null
}

output "gateway_id" {
  description = "The ID of the Gateway."
  value       = var.gateway ? module.hub.gateway_id : null
}

output "kube_config" {
  value = module.spoke_aks.kube_config
}

output "application_gateway_public_ip_address" {
  description = "The public IP address of the Application Gateway."
  value       = var.application_gateway ? module.hub.application_gateway_public_ip_address : null
}

output "acr_name" {
  description = "The Container Registry name this cluster has AcrPull access to."
  value = module.spoke_aks.acr_name
}

output "acr_id" {
  description = "The Container Registry ID this cluster has AcrPull access to."
  value = module.spoke_aks.acr_id
}

output "acr_endpoint" {
  description = "The Container Registry endpoint."
  value = module.spoke_aks.acr_endpoint
}

output "aks_lb_snet_id" {
  value = module.spoke_aks.aks_lb_subnet_id
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace to log Application Gateway."
  value       = module.hub.log_analytics_workspace_id
}

output "AZURE_AKS_CLUSTER_NAME" {
  description = "The name of the AKS cluster."
  value       = module.spoke_aks.AZURE_AKS_CLUSTER_NAME
}

output "aks_resource_group_name" {
  description = "The name of the AKS resource group."
  value       = module.spoke_aks.resource_group_name
}

output "key_vault_name" {
  description = "The name of the Key Vault."
  value       = module.spoke_aks.key_vault_name
}

output "kubelet_identity_client_id" {
  description = "The client ID of the kubelet managed identity."
  value       = module.spoke_aks.kubelet_identity_client_id
}