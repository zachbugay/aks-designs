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
  instance    = 001
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
  resource_group_name = module.resource_group.name
  location            = local.location
  environment         = local.environment
  workload            = local.workload
  instance            = local.instance
  address_space       = ["10.0.0.0/24"]
}

module "subnet_in" {
  source               = "../../../subnet"
  resource_group_name  = module.resource_group.name
  location             = local.location
  environment          = local.environment
  workload             = local.workload
  instance             = local.instance
  virtual_network_name = module.virtual_network.name
  address_prefixes     = ["10.0.0.0/25"]
}

module "subnet_out" {
  source               = "../../../subnet"
  resource_group_name  = module.resource_group.name
  location             = local.location
  environment          = local.environment
  workload             = local.workload
  instance             = local.instance
  virtual_network_name = module.virtual_network.name
  address_prefixes     = ["10.0.0.0/25"]
}

module "private_dns_resolver" {
  source                      = "../../../private_dns_resolver"
  resource_group_name         = module.resource_group.name
  location                    = local.location
  environment                 = local.environment
  workload                    = local.workload
  instance                    = local.instance
  virtual_network_id          = module.virtual_network.id
  inbound_endpoint_subnet_id  = module.subnet_in.id
  outbound_endpoint_subnet_id = module.subnet_out.id
}

module "private_dns_resolver_dns_forwarding_ruleset" {
  source                                     = "../../"
  location                                   = local.location
  environment                                = local.environment
  workload                                   = local.workload
  instance                                   = local.instance
  resource_group_name                        = module.resource_group.name
  private_dns_resolver_outbound_endpoint_ids = [module.private_dns_resolver.outbound_endpoint_id]
  virtual_network_id                         = module.virtual_network.id
}
