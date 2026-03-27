output "id" {
  description = "The ID of the Linux Virtual Machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "name" {
  description = "The name of the Linux Virtual Machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "resource_group_name" {
  description = "The name of the resource group in which the Linux Virtual Machine is created."
  value       = azurerm_linux_virtual_machine.this.resource_group_name
}

output "admin_username" {
  description = "The username of the Linux Virtual Machine."
  value       = var.admin_username
}

output "admin_password" {
  description = "The password of the Linux Virtual Machine."
  value       = var.admin_password
  sensitive   = true
}

output "admin_public_key" {
  description = "The public key of the Linux Virtual Machine."
  value       = tls_private_key.this.public_key_openssh
  sensitive   = true
}

output "admin_private_key" {
  description = "Admin Private SSH Key (openssh)"
  value       = tls_private_key.this.private_key_openssh
  sensitive   = true
}

output "private_ip_address" {
  description = "The private IP address of the Linux Virtual Machine."
  value       = azurerm_network_interface.this.private_ip_address
}

output "network_interface_id" {
  description = "The ID of the Network Interface."
  value       = azurerm_network_interface.this.id
}

output "source_image_reference_offer" {
  description = "The offer of the source image used to create the Linux Virtual Machine."
  value       = var.source_image_reference_offer
}