terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.0.0"
    }
  }
}

locals {
  location    = "westus3"
  environment = "nonprod"
  workload    = "shared-hub"
}

module "resource_group" {
  source      = "../../../resource_group"
  location    = local.location
  environment = local.environment
  workload    = local.workload
}

module "route_table" {
  source              = "../../../route_table"
  resource_group_name = module.resource_group.name
  location            = local.location
  environment         = local.environment
  workload            = local.workload
}

module "route" {
  source                 = "../../"
  resource_group_name    = module.resource_group.name
  route_table_name       = module.route_table.name
  address_prefix         = "10.0.0.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.0.1.4"
}
