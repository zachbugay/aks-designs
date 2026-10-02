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
  admin_object_ids  = var.admin_object_ids != "" ? split(",", var.admin_object_ids) : null
}

module "spoke_aks" {
  source = "../../modules/pattern_spoke_aks"
  admin_object_ids                                 = local.admin_object_ids
  alert_email                                      = var.alert_email
  application_gateway                              = var.application_gateway
  application_gateway_for_containers               = var.application_gateway_for_containers
  authorized_ip_ranges                             = var.authorized_ip_ranges
  deployment_token                                 = random_string.deployment_token
  dns_servers                                      = var.dns_servers
  enable_private_api_server                        = var.enable_private_api_server
  environment                                      = var.aks_environment
  hub_resource_group_name                          = var.hub_resource_group_name
  hub_virtual_network_id                           = var.hub_virtual_network_id
  instance                                         = var.instance
  key_vault_private_dns_zone_resource_id           = var.private_dns_zones["privatelink.vaultcore.azure.net"].id
  kubernetes_version                               = var.aks_version
  location                                         = var.location
  log_analytics_workspace_id                       = var.hub_log_analytics_workspace_id
  monitor_workspace_id                             = var.hub_azure_monitor_workspace_id
  private_dns_zone_id                              = var.private_dns_zones["privatelink.${var.location}.azmk8s.io"].id
  private_endpoint_subnet_resource_id              = module.hub.private_endpoint_subnet_id
  subnets_next_hop                                 = var.firewall_enabled ? var.firewall_private_ip : null
  tags                                             = var.tags
  tenant_id                                        = var.tenant_id
  virtual_network_gateway_exists                   = var.virtual_network_gateway_exists
  vm_size                                          = var.aks_node_pool_vm_size
  vnet_address_space                               = [var.aks_spoke_vnet_address_space]
  workload                                         = "apps"

  application_gateway_applications = {
    httpbin = {
      hostname                    = "zachb-httpbin.duckdns.org"
      https_port                  = 443
      http_port                   = 80
      probe_path                  = "/get"
      probe_protocol              = "Https"
      probe_interval              = 30
      probe_timeout               = 30
      probe_unhealthy_threshold   = 3
      probe_status_codes          = ["200-399"]
      backend_port                = 443
      backend_protocol            = "Https"
      backend_request_timeout     = 30
      cookie_based_affinity       = "Disabled"
      rule_type                   = "Basic"
      redirect_type               = "Permanent"
      path_rules                  = []
      https_rule_priority         = 100
      http_redirect_rule_priority = 90
    }
    podinfo = {
      hostname                    = "zachb-podinfo.duckdns.org"
      https_port                  = 443
      http_port                   = 80
      probe_path                  = "/healthz"
      probe_protocol              = "Https"
      probe_interval              = 30
      probe_timeout               = 30
      probe_unhealthy_threshold   = 3
      probe_status_codes          = ["200-399"]
      backend_port                = 443
      backend_protocol            = "Https"
      backend_request_timeout     = 30
      cookie_based_affinity       = "Disabled"
      rule_type                   = "Basic"
      redirect_type               = "Permanent"
      path_rules                  = []
      https_rule_priority         = 110
      http_redirect_rule_priority = 80
    }
  }

  depends_on = [
    module.hub,
    module.virtual_network_peerings_dns,
    module.virtual_network_peerings_monitoring
  ]
}

module "route_to_spoke_aks" {
  source                 = "../../modules/base_modules/route"
  count                  = var.firewall.enabled ? 1 : 0
  address_prefix         = var.aks_spoke_vnet_address_space
  next_hop_in_ip_address = module.hub.firewall_private_ip
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = module.hub.resource_group_name
  route_table_name       = module.hub.gateway_route_table_name
}
