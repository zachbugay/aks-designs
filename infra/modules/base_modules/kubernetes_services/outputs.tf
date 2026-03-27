output "name" {
  description = "name of the cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "acr_id" {
  description = "The Container Registry ID this cluster has AcrPull access to."
  value       = var.container_registry_id
}

output "id" {
  description = "Resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}


output "client_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "current_kubernetes_version" {
  description = "Current kubernetes version"
  value       = azurerm_kubernetes_cluster.this.current_kubernetes_version
}

output "host" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.this.kube_config
  sensitive = true
}

output "fqdn" {
  value     = azurerm_kubernetes_cluster.this.fqdn
  sensitive = true
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL for workload identity federation"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_principal_id" {
  description = "The principal ID of the kubelet managed identity."
  value       = azurerm_user_assigned_identity.kubelet_identity.principal_id
}

output "kubelet_identity_client_id" {
  description = "The client ID of the kubelet managed identity."
  value       = azurerm_user_assigned_identity.kubelet_identity.client_id
}

# output "alb_identity_principal_id" {
#   description = "The principal ID of the Application Load Balancer managed identity."
#   value       = try(one(data.azurerm_user_assigned_identity.applicationloadbalancer).principal_id, null)
# }
