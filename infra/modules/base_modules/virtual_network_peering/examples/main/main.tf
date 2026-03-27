terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
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

module "virtual_network_1" {
  source              = "../../../virtual_network"
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = "001"
  resource_group_name = module.resource_group.name
  address_space       = ["10.0.0.0/24"]
}

module "virtual_network_2" {
  source              = "../../../virtual_network"
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = "002"
  resource_group_name = module.resource_group.name
  address_space       = ["10.0.1.0/24"]
}

module "virtual_network_peering" {
  source                    = "../../../virtual_network_peering"
  resource_group_name       = module.resource_group.name
  virtual_network_name      = module.virtual_network_1.name
  remote_virtual_network_id = module.virtual_network_2.id
}