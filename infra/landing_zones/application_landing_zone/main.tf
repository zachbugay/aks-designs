provider "azurerm" {
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  use_oidc                        = true
  subscription_id                 = var.subscription_id
  tenant_id                       = var.tenant_id
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
  config   = yamldecode(file("${path.root}/${var.config_file}"))
  common   = local.config.landing_zones.common
  aks      = local.config.landing_zones.application.aks
  platform = yamldecode(file("${path.root}/../platform_landing_zone/outputs/${local.config.environment}.outputs.generated.yaml")).platform_landing_zone

  tags = merge(
    local.common.tags,
    { environment = local.config.environment },
    { workload_environment = local.config.workload_environment }
  )
}

module "spoke_aks" {
  source                                 = "../../modules/pattern_spoke_aks"
  admin_object_ids                       = local.common.admin_object_ids
  alert_emails                           = local.common.alert_emails
  application_gateway                    = local.aks.application_gateway
  application_gateway_applications       = local.aks.application_gateway_applications
  application_gateway_for_containers     = local.aks.application_gateway_for_containers
  application_routing_addon_gateway_api  = local.aks.application_routing_addon_gateway_api
  authorized_ip_ranges                   = local.aks.authorized_ip_ranges
  deployment_token                       = random_string.deployment_token.result
  dns_servers                            = local.platform.dns_servers
  enable_private_api_server              = local.aks.enable_private_api_server
  environment                            = local.config.environment
  hub_resource_group_name                = local.platform.hub_resource_group_name
  hub_virtual_network_id                 = local.platform.hub_virtual_network_id
  instance                               = local.aks.instance
  key_vault_private_dns_zone_resource_id = local.platform.private_dns_zones["privatelink.vaultcore.azure.net"].id
  kubernetes_version                     = local.aks.kubernetes_version
  location                               = var.location
  log_analytics_workspace_id             = local.platform.log_analytics_workspace_id
  monitor_workspace_id                   = local.platform.azure_monitor_workspace_id
  private_dns_zone_id                    = local.platform.private_dns_zones["privatelink.${var.location}.azmk8s.io"].id
  private_endpoint_subnet_resource_id    = local.platform.hub_private_endpoint_subnet_id
  subnets_next_hop                       = local.platform.firewall.enabled ? local.platform.firewall.private_ip : null
  system_node_pool                       = local.aks.system_node_pool
  tags                                   = local.tags
  tenant_id                              = var.tenant_id
  user_node_pools                        = local.aks.user_node_pools
  virtual_network_gateway_exists         = local.platform.virtual_network_gateway.enabled
  vnet_address_space                     = local.aks.vnet_address_space
  workload                               = local.aks.workload
}

module "route_to_spoke_aks" {
  source                 = "../../modules/base_modules/route"
  count                  = local.platform.firewall.enabled ? 1 : 0
  address_prefix         = local.aks.vnet_address_space[0]
  next_hop_in_ip_address = local.platform.firewall.private_ip
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = local.platform.hub_resource_group_name
  route_table_name       = local.platform.virtual_network_gateway.route_table_name

  depends_on = [module.spoke_aks]
}
