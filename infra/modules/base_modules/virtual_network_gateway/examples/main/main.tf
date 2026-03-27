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
  instance    = local.instance
}

module "virtual_network" {
  source              = "../../../virtual_network"
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
  resource_group_name = module.resource_group.name
  address_space       = ["10.0.0.0/24"]
}

module "subnet" {
  source               = "../../../subnet"
  location             = local.location
  environment          = local.environment
  workload             = local.workload
  instance             = local.instance
  custom_name          = "GatewaySubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = ["10.0.0.0/25"]
}

module "public_ip" {
  source              = "../../../public_ip"
  count               = 2
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
  resource_group_name = module.resource_group.name
}

module "gateway" {
  source              = "../.."
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
  resource_group_name = module.resource_group.name
  ip_configurations = [for index, pip in module.public_ip : {
    name                 = "ipconfig${index + 1}"
    public_ip_address_id = pip.id
    subnet_id            = module.subnet.id
  }]
}
