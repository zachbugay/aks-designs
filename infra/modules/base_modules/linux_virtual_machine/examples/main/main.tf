terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.0.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2.31"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
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
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = ["10.0.0.0/25"]
}

module "linux_virtual_machine" {
  source              = "../../../linux_virtual_machine"
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
  resource_group_name = module.resource_group.name
  subnet_id           = module.subnet.id
}
