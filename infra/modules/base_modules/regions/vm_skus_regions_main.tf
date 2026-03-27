# Providers
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }
}

# Variables
variable "region_names" {
  description = "List of regions to query VM SKU availability zones for"
  type        = list(string)
  default     = ["westus3"]
}

variable "vm_skus" {
  description = "List of VM SKUs to check availability zone support for"
  type        = list(string)
  default     = ["Standard_D2s_v3"]
}

# Main TF Code
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.11.0"

  region_filter   = var.region_names
  use_cached_data = false
}

data "azurerm_subscription" "current" {}

data "azapi_resource_list" "compute_skus" {
  for_each  = toset(var.region_names)
  type      = "Microsoft.Compute/skus@2021-07-01"
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"

  query_parameters = {
    "$filter" = ["location eq '${each.value}'"]
  }

  response_export_values = {
    skus = "value[?resourceType == 'virtualMachines'].{name: name, zones: locationInfo[0].zones}"
  }
}

locals {
  vm_sku_zones = {
    for sku in var.vm_skus : sku => {
      for region in var.region_names : region => try(
        one([for s in data.azapi_resource_list.compute_skus[region].output.skus : s.zones if s.name == sku]),
        []
      )
    }
  }
}

# Outputs
output "vm_sku_region_zones" {
  description = "Map of region to VM SKU to availability zones. e.g. { westus3 = { Standard_D2s_v3 = [\"1\", \"2\", \"3\"] } }"
  value       = local.vm_sku_zones
}
# ---- Invoking the custom terraform module ---- # 

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
