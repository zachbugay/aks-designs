locals {
  remote_virtual_network_name = split("/", var.remote_virtual_network_id)[8]
}

resource "azurecaf_name" "this" {
  name          = "${var.virtual_network_name}-to-${local.remote_virtual_network_name}"
  resource_type = "azurerm_virtual_network_peering"
  clean_input   = true
}

resource "azurerm_virtual_network_peering" "this" {
  name                         = coalesce(var.custom_name, azurecaf_name.this.result)
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.virtual_network_name
  remote_virtual_network_id    = var.remote_virtual_network_id
  allow_virtual_network_access = var.allow_virtual_network_access
  allow_forwarded_traffic      = var.allow_forwarded_traffic
  allow_gateway_transit        = var.allow_gateway_transit
  use_remote_gateways          = var.use_remote_gateways
}
