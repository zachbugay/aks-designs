terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2.34"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.12"
    }
    # azurelocations = {
    #   source  = "azurerm/locations/azure"
    #   version = "~> 0.2.10"
    # }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.3.0"
    }
  }
}

# data "azurerm_kubernetes_cluster" "aks" {
#   name                = module.pattern_hub_and_spoke.AZURE_AKS_CLUSTER_NAME
#   resource_group_name = module.pattern_hub_and_spoke.aks_resource_group_name
# }

# TODO: Remove the need for Terraform Kubernetes Provider.
# provider "kubernetes" {
#   host                   = one(data.azurerm_kubernetes_cluster.aks.kube_admin_config).host
#   cluster_ca_certificate = base64decode(one(data.azurerm_kubernetes_cluster.aks.kube_admin_config).cluster_ca_certificate)
# }

provider "azapi" {
  skip_provider_registration = false
}

