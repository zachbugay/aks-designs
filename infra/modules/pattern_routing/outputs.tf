output "route_table_name" {
  description = "The name of the Route Table."
  value       = module.route_table.name
}

output "route_table_id" {
  description = "The ID of the Route Table."
  value       = module.route_table.id
}
