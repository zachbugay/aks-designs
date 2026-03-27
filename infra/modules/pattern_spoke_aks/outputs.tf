output "resource_group_name" {
  description = "The name of the resource group of the spoke."
  value       = module.resource_group.name
}

output "AZURE_AKS_CLUSTER_NAME" {
  description = "Name of the AKS cluster"
  value       = module.aks.name
}

output "acr_id" {
  description = "The Container Registry ID this cluster has AcrPull access to."
  value       = module.acr.id
}

output "acr_name" {
  description = "The Container Registry name this cluster has AcrPull access to."
  value       = module.acr.name
}

output "acr_endpoint" {
  description = "The Container Registry name this cluster has AcrPull access to."
  value       = module.acr.endpoint
}

output "virtual_network_name" {
  description = "The name of the virtual network of the spoke."
  value       = module.virtual_network.name
}

output "virtual_network_id" {
  description = "The ID of the virtual network of the spoke."
  value       = module.virtual_network.id
}

output "aks_lb_subnet_id" {
  description = "The ID of the AKS load balancer subnet."
  value       = module.subnets["aks-lb"].id
}

output "network_security_group_id" {
  description = "The ID of the Network Security Group."
  value       = var.network_security_group ? module.network_security_group[0].id : null
}

output "cluster_ca_certificate" {
  value     = module.aks.cluster_ca_certificate
  sensitive = true
}

output "kube_config" {
  value     = module.aks.kube_config
  sensitive = true
}

output "fqdn" {
  value     = module.aks.fqdn
  sensitive = true
}

output "current_kubernetes_version" {
  description = "Current kubernetes version"
  value       = module.aks.current_kubernetes_version
}

output "key_vault_id" {
  description = "The ID of the Key Vault."
  value       = module.key_vault.id
}

output "key_vault_name" {
  description = "The name of the Key Vault."
  value       = module.key_vault.name
}

output "kubelet_identity_client_id" {
  description = "The client ID of the kubelet managed identity."
  value       = module.aks.kubelet_identity_client_id
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL for workload identity federation"
  value       = module.aks.oidc_issuer_url
}