terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.62.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
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

module "regions" {
  source       = "../../"
  region_names = [local.location]
  vm_skus      = ["Standard_D2s_v3", "Standard_D4s_v3", "Standard_D16s_v6"]
}

output "vm_sku_region_zones" {
  description = "Map of region to VM SKU to availability zones."
  value       = module.regions.vm_sku_region_zones
}
