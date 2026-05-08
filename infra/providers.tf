terraform {
  required_version = "> 1.14.5"
  required_providers {
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2.32"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.72.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
    }
  }
}
