output "id" {
  description = "ID of the container registry."
  value       = module.acr.resource_id
}

output "name" {
  description = "Name of the container registry."
  value       = module.acr.name
}

output "endpoint" {
  description = "Endpoint for the container registry."
  value = "${module.acr.name}.azurecr.io"
}
