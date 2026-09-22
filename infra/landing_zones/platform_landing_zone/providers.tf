terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6.0"
    }
    # https://registry.terraform.io/providers/aztfmod/azurecaf/1.2.34
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2.34"
    }
    # https://registry.terraform.io/providers/Azure/azapi/latest
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.12"
    }
    # azurelocations = {
    #   source  = "azurerm/locations/azure"
    #   version = "~> 0.2.10"
    # }
    # https://registry.terraform.io/providers/hashicorp/cloudinit/latest
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.4.1"
    }
    # https://registry.terraform.io/providers/hashicorp/local/latest
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4.1"
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

