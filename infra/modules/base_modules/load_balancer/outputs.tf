output "id" {
  description = "The ID of the Load Balancer."
  value       = azurerm_lb.this.id
}

output "name" {
  description = "The name of the Load Balancer."
  value       = azurerm_lb.this.name
}

output "backend_address_pool_id" {
  description = "The ID of the backend address pool."
  value       = azurerm_lb_backend_address_pool.this.id
}

output "frontend_ip_configuration_id" {
  description = "The ID of the frontend IP configuration."
  value       = azurerm_lb.this.frontend_ip_configuration[0].id
}
