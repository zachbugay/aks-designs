terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2.31"
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

module "log_analytics_workspace" {
  source              = "../../"
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
  resource_group_name = module.resource_group.name
}
