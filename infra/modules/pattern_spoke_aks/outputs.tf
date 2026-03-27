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

output "aks_alb_subnet_id" {
  description = "The ID of the AKS application load balancer subnet."
  value       = module.subnets["aks-alb"].id
}

output "network_security_group_id" {
  description = "The ID of the Network Security Group."
  value       = var.network_security_group ? module.network_security_group[0].id : null
}


output "client_certificate" {
  value = module.aks.client_certificate
}

output "client_key" {
  value = module.aks.client_key
}

output "cluster_ca_certificate" {
  value     = module.aks.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "current_kubernetes_version" {
  description = "Current kubernetes version"
  value       = module.aks.current_kubernetes_version
}

output "host" {
  value = module.aks.host
}

output "kube_config" {
  value     = module.aks.kube_config
  sensitive = true
}

output "fqdn" {
  value     = module.aks.fqdn
  sensitive = true
}

output "key_vault_id" {
  description = "The ID of the Key Vault."
  value       = module.private_key_vault.id
}

output "key_vault_name" {
  description = "The name of the Key Vault."
  value       = module.private_key_vault.name
}

output "kubelet_identity_client_id" {
  description = "The client ID of the kubelet managed identity."
  value       = module.aks.kubelet_identity_client_id
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL for workload identity federation"
  value       = module.aks.oidc_issuer_url
}

output "application_gateway_id" {
  description = "The ID of the Application Gateway."
  value       = var.application_gateway ? module.application_gateway[0].id : null
}

output "application_gateway_public_ip_address" {
  description = "The public IP address of the Application Gateway."
  value       = var.application_gateway ? module.public_ip_agw[0].ip_address : null
}
