provider "azurerm" {
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  use_oidc                        = true
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    servicebus {
      auto_delete_subscription_default_rule = true
    }
  }
}

data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_string" "deployment" {
  length  = 4
  special = false
  upper   = false
}

locals {
  admin_object_ids  = var.admin_object_ids != "" ? split(",", var.admin_object_ids) : null
  p2s_vpn_enabled   = (var.virtual_network_gateway && var.point_to_site_vpn)
  vpn_auth_types    = (var.virtual_network_gateway && var.point_to_site_vpn) ? ["AAD"] : null
  agw_root_cert_pem = var.application_gateway_trusted_root_certificate_base64 != "" ? base64decode(var.application_gateway_trusted_root_certificate_base64) : null
}

# module "pattern_hub_and_spoke" {
#   source = "../modules/pattern_hub_and_spoke"
#
#   address_space_hub                                = ["10.100.0.0/22"]
#   address_space_spoke_aks                          = ["10.100.12.0/22"]
#   address_space_spoke_dns                          = ["10.100.4.0/24"]
#   address_space_spoke_private_monitoring           = ["10.100.5.0/27"]
#   admin_object_ids                                 = local.admin_object_ids
#   alert_email                                      = var.alert_email
#   application_gateway                              = true
#   application_gateway_for_containers               = false
#   application_gateway_trusted_root_certificate_pem = local.agw_root_cert_pem
#   bastion                                          = false
#   connection_monitor                               = true
#   environment                                      = var.environment
#   enable_private_api_server                        = true
#   firewall                                         = var.firewall
#   gateway                                          = var.virtual_network_gateway
#   p2s_vpn                                          = local.p2s_vpn_enabled
#   vpn_auth_types                                   = local.vpn_auth_types
#   location                                         = var.location
#   nat_gateway_public_ip_count                      = var.nat_gateway_public_ip_count
#   network_security_group                           = true
#   private_monitoring                               = true
#   random_string                                    = random_string.deployment.result
#   spoke_dns                                        = true
#   tenant_id                                        = var.tenant_id
#   update_management                                = true
#   vm_size                                          = var.aks_node_pool_vm_size
#   workload                                         = "shared-hub"
#   workload_environment                             = var.workload_environment
#
#   tags = var.common_tags
# }

