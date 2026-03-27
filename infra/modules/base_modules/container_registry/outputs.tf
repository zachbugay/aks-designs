output "id" {
  description = "ID of the container registry."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Name of the container registry."
  value       = azurerm_container_registry.this.name
}

output "endpoint" {
  description = "Endpoint for the container registry."
  value       = azurerm_container_registry.this.login_server
}
