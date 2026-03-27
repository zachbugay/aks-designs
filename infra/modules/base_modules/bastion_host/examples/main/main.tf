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

module "public_ip" {
  source              = "../../../public_ip"
  resource_group_name = module.resource_group.name
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
}

module "bastion_host" {
  source               = "../../"
  resource_group_name  = module.resource_group.name
  location             = local.location
  environment          = local.environment
  workload             = local.workload
  instance             = local.instance
  public_ip_address_id = module.public_ip.id
}
