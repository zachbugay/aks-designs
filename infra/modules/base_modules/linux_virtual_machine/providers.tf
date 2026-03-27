terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azurecaf = {
      source = "aztfmod/azurecaf"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
