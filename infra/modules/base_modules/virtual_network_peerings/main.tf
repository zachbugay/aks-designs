locals {
  virtual_network_1_name        = split("/", var.virtual_network_1_id)[8]
  virtual_network_2_name        = split("/", var.virtual_network_2_id)[8]
  enable_gateway_transit_1_to_2 = (var.virtual_network_1_hub && var.gateway_exists)
}

module "peering_1_to_2" {
  source                       = "../virtual_network_peering"
  resource_group_name          = var.virtual_network_1_resource_group_name
  virtual_network_name         = local.virtual_network_1_name
  remote_virtual_network_id    = var.virtual_network_2_id
  allow_virtual_network_access = var.allow_virtual_network_access
  allow_forwarded_traffic      = var.allow_forwarded_traffic
  allow_gateway_transit        = local.enable_gateway_transit_1_to_2
  use_remote_gateways          = false
}

module "peering_2_to_1" {
  source                       = "../virtual_network_peering"
  resource_group_name          = var.virtual_network_2_resource_group_name
  virtual_network_name         = local.virtual_network_2_name
  remote_virtual_network_id    = var.virtual_network_1_id
  allow_virtual_network_access = var.allow_virtual_network_access
  allow_forwarded_traffic      = var.allow_forwarded_traffic
  allow_gateway_transit        = false
  use_remote_gateways          = local.enable_gateway_transit_1_to_2

  depends_on = [
    module.peering_1_to_2
  ]
}
