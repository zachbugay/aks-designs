output "id" {
  description = "The ID of the Key Vault."
  value       = module.key_vault.id
}

output "name" {
  description = "The name of the Key Vault."
  value       = module.key_vault.name
}

output "resource_group_name" {
  description = "The name of the resource group containing the Key Vault."
  value       = module.key_vault.resource_group_name
}

output "private_endpoint_id" {
  description = "The ID of the Key Vault Private Endpoint."
  value       = azurerm_private_endpoint.this.id
}

output "private_endpoint_ip_address" {
  description = "The private IP address of the Key Vault Private Endpoint."
  value       = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}

output "managed_identity_id" {
  description = "The ID of the User Assigned Managed Identity with Key Vault Administrator access."
  value       = azurerm_user_assigned_identity.this.id
}

output "managed_identity_name" {
  description = "The name of the User Assigned Managed Identity with Key Vault Administrator access."
  value       = azurerm_user_assigned_identity.this.name
}

output "managed_identity_principal_id" {
  description = "The principal ID of the User Assigned Managed Identity with Key Vault Administrator access."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "managed_identity_client_id" {
  description = "The client ID of the User Assigned Managed Identity with Key Vault Administrator access."
  value       = azurerm_user_assigned_identity.this.client_id
}
