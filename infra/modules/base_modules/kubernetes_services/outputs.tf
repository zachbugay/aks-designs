output "name" {
  description = "name of the cluster"
  value       = module.aks.name
}

output "acr_id" {
  description = "The Container Registry ID this cluster has AcrPull access to."
  value       = var.container_registry_id
}

output "id" {
  description = "Resource ID of the AKS cluster"
  value       = module.aks.resource_id
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

output "oidc_issuer_url" {
  description = "The OIDC issuer URL for workload identity federation"
  value       = module.aks.oidc_issuer_profile_issuer_url
}

output "kubelet_identity_principal_id" {
  description = "The principal ID of the kubelet managed identity."
  value       = azurerm_user_assigned_identity.kubelet_identity.principal_id
}

output "kubelet_identity_client_id" {
  description = "The client ID of the kubelet managed identity."
  value       = azurerm_user_assigned_identity.kubelet_identity.client_id
}

output "alb_identity_principal_id" {
  description = "The principal ID of the Application Load Balancer managed identity."
  value       = var.application_gateway_for_containers ? data.azurerm_user_assigned_identity.applicationloadbalancer.principal_id : null
}
