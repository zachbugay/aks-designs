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
  p2s_vpn_enabled   = (var.virtual_network_gateway && var.point_to_site_vpn)
  vpn_auth_types    = (var.virtual_network_gateway && var.point_to_site_vpn) ? ["AAD"] : null
  agw_root_cert_pem = var.application_gateway_trusted_root_certificate_base64 != "" ? base64decode(var.application_gateway_trusted_root_certificate_base64) : null
}

module "spoke_aks" {
  source                                           = "../pattern_spoke_aks"
  address_space                                    = var.address_space_spoke_aks
  admin_object_ids                                 = var.admin_object_ids
  alert_email                                      = var.alert_email
  application_gateway                              = var.application_gateway
  application_gateway_backend_ip_addresses         = ["10.100.12.8"]
  application_gateway_for_containers               = var.application_gateway_for_containers
  application_gateway_trusted_root_certificate_pem = var.application_gateway_trusted_root_certificate_pem
  authorized_ip_ranges                             = local.authorized_ip_ranges
  dns_servers                                      = local.vnet_dns_servers
  enable_private_api_server                        = var.enable_private_api_server
  environment                                      = var.workload_environment
  firewall                                         = var.firewall.enabled
  gateway_exists                                   = var.virtual_network_gateway
  kubernetes_version                               = var.aks_kubernetes_version
  hub_resource_group_name                          = module.hub.resource_group_name
  hub_virtual_network_id                           = module.hub.virtual_network_id
  instance                                         = var.instance
  key_vault_private_dns_zone_resource_id           = local.spoke_dns_enabled ? module.spoke_dns[0].private_dns_zones["privatelink.vaultcore.azure.net"]["id"] : null
  location                                         = var.location
  log_analytics_workspace_id                       = module.hub.log_analytics_workspace_id
  monitor_workspace_id                             = module.hub.azure_monitor_workspace_id
  private_dns_zone_id                              = local.spoke_dns_enabled ? module.spoke_dns[0].private_dns_zones["privatelink.${var.location}.azmk8s.io"]["id"] : null
  private_endpoint_subnet_resource_id              = module.hub.private_endpoint_subnet_id
  deployment_token                                 = var.deployment_token
  subnets_next_hop                                 = var.firewall.enabled ? module.hub.firewall_private_ip : null
  tags                                             = local.tags
  tenant_id                                        = var.tenant_id
  vm_size                                          = var.vm_size
  workload                                         = "ent-apps"

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
  source                 = "../base_modules/route"
  count                  = (var.firewall.enabled && var.address_space_spoke_aks != null) ? 1 : 0
  address_prefix         = var.address_space_spoke_aks[0]
  next_hop_in_ip_address = module.hub.firewall_private_ip
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = module.hub.resource_group_name
  route_table_name       = module.hub.gateway_route_table_name
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
#   deployment_token                                    = deployment_token.deployment.result
#   spoke_dns                                        = true
#   tenant_id                                        = var.tenant_id
#   update_management                                = true
#   vm_size                                          = var.aks_node_pool_vm_size
#   workload                                         = "shared-hub"
#   workload_environment                             = var.workload_environment
#
#   tags = var.common_tags
# }

