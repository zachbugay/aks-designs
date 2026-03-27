output "id" {
  description = "Route table route id."
  value       = azurerm_route.this.id
}

output "name" {
  description = "Route table route name."
  value       = azurerm_route.this.name
}