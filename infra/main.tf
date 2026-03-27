provider "azurerm" {
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  use_oidc                        = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}
data "http" "current_ip" {
  url = "https://ipv4.icanhazip.com"
}

resource "random_string" "deployment" {
  length  = 4
  special = false
  upper   = false
}

locals {
  admin_group_object_ids = var.admin_group_object_ids != "" ? split(",", var.admin_group_object_ids) : null
}

module "pattern_hub_and_spoke" {
  source                                 = "./modules/pattern_hub_and_spoke"
  address_space_hub                      = ["10.100.0.0/22"]
  address_space_spoke_aks                = ["10.100.12.0/22"]
  address_space_spoke_dns                = ["10.100.4.0/24"]
  address_space_spoke_private_monitoring = ["10.100.5.0/27"]
  admin_group_object_ids                 = local.admin_group_object_ids
  alert_email                            = var.alert_email
  application_gateway                    = false
  application_gateway_for_containers     = true
  authorized_ip_ranges                   = ["${chomp(data.http.current_ip.response_body)}/32"]
  bastion                                = false
  connection_monitor                     = true
  environment                            = var.environment
  workload_environment                   = var.workload_environment
  firewall                               = var.firewall
  firewall_sku_tier                      = "Basic"
  gateway                                = var.virtual_network_gateway
  location                               = var.location
  nat_gateway_public_ip_count            = 1
  network_security_group                 = true
  private_monitoring                     = true
  random_string                          = random_string.deployment.result
  spoke_dns                              = true
  tenant_id                              = var.tenant_id
  update_management                      = true
  vm_size                                = var.aks_node_pool_vm_size
  workload                               = "shared-hub"
}

# provider "kubernetes" {
#   host                   = one(data.azurerm_kubernetes_cluster.default.kube_config).host
#   cluster_ca_certificate = base64decode(one(data.azurerm_kubernetes_cluster.default.kube_config).cluster_ca_certificate)

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "kubelogin"
#     args = [
#       "get-token",
#       "--login",
#       "azurecli",
#       "--server-id",
#       "6dae42f8-4368-4678-94ff-3960e28e3630"
#     ]
#   }
# }

# provider "helm" {
#   kubernetes = {
#     host                   = one(data.azurerm_kubernetes_cluster.default.kube_config).host
#     cluster_ca_certificate = base64decode(one(data.azurerm_kubernetes_cluster.default.kube_config).cluster_ca_certificate)

#     exec = {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "kubelogin"
#       args = [
#         "get-token",
#         "--login",
#         "azurecli",
#         "--server-id",
#         "6dae42f8-4368-4678-94ff-3960e28e3630"
#       ]
#     }
#   }
# }
