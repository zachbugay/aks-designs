terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2.31"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.60.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.7.0"
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
  instance    = "001"
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
  instance            = local.instance
}

module "virtual_network" {
  source              = "../../../virtual_network"
  resource_group_name = module.resource_group.name
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
  address_space       = ["10.0.0.0/24"]
}

module "subnet" {
  source               = "../../../subnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  location             = local.location
  environment          = local.environment
  workload             = local.workload
  instance             = local.instance
  address_prefixes     = ["10.0.0.0/25"]
}

module "subnet_route_table_association" {
  source         = "../../"
  subnet_id      = module.subnet.id
  route_table_id = module.route_table.id
}
