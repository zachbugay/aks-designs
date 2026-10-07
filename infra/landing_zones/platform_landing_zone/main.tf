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

resource "random_string" "deployment_token" {
  length  = 4
  special = false
  upper   = false
}

locals {
  config = yamldecode(file("${path.root}/${var.config_file}"))

  address_space_hub                      = local.config.landing_zones.platform.address_space_hub
  address_space_spoke_dns                = local.config.landing_zones.platform.address_space_spoke_dns
  address_space_spoke_private_monitoring = local.config.landing_zones.platform.address_space_spoke_private_monitoring
  admin_object_ids                       = local.config.landing_zones.common.admin_object_ids
  common_tags                            = local.config.landing_zones.common.tags
  environment                            = local.config.environment
  firewall                               = local.config.landing_zones.platform.firewall
  nat_gateway                            = local.config.landing_zones.platform.nat_gateway
  network_security_group                 = local.config.landing_zones.platform.network_security_group
  private_monitoring                     = local.config.landing_zones.platform.private_monitoring
  spoke_dns                              = local.config.landing_zones.platform.spoke_dns
  virtual_network_gateway                = local.config.landing_zones.platform.virtual_network_gateway
  workload                               = local.config.workload
  workload_environment                   = local.config.workload_environment
}

module "pattern_hub_and_spoke" {
  source = "../../modules/pattern_hub_and_spoke"

  # Computed
  deployment_token = random_string.deployment_token.result
  tags = merge(
    local.common_tags,
    { "environment" = local.environment },
    { "workload_environment" = local.workload_environment }
  )

  # Variables
  location  = var.location
  tenant_id = var.tenant_id

  # YAML Definitions
  address_space_hub                      = local.address_space_hub
  address_space_spoke_dns                = local.address_space_spoke_dns
  address_space_spoke_private_monitoring = local.address_space_spoke_private_monitoring
  admin_object_ids                       = local.admin_object_ids
  environment                            = local.environment
  firewall                               = local.firewall
  nat_gateway_public_ip_count            = local.nat_gateway.public_ip_count
  network_security_group                 = local.network_security_group
  p2s_vpn                                = local.virtual_network_gateway.vpn.p2s_enabled
  private_monitoring                     = local.private_monitoring
  spoke_dns                              = local.spoke_dns
  virtual_network_gateway                = local.virtual_network_gateway.enabled
  vpn_auth_types                         = local.virtual_network_gateway.vpn.auth_types
  workload                               = local.workload
  workload_environment                   = local.workload_environment
}
