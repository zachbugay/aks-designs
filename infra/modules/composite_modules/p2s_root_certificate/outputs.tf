output "name" {
  description = "The name of the Point-to-Site root certificate."
  value       = local.name
}

output "public_cert_data" {
  description = "The base64 encoded DER public certificate data for the Virtual Network Gateway root certificate."
  value       = local.public_cert_data
}
