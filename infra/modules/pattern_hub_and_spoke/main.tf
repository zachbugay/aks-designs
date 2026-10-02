locals {
  module_tags = tomap(
    {
      terraform-azurerm-composable-level3 = "pattern_hub_and_spoke"
    }
  )

  tags = merge(
    local.module_tags,
    var.tags
  )

  authorized_ip_ranges = concat((var.authorized_ip_ranges == null ? [] : var.authorized_ip_ranges))
  virtual_machines     = merge([for k, v in module.spoke : v.virtual_machines]...)
  dns_servers          = var.dns_servers != null ? var.dns_servers : (var.spoke_dns ? [module.spoke_dns[0].inbound_endpoint_ip] : [])
  vnet_dns_servers     = var.dns_servers != null ? var.dns_servers : var.spoke_dns ? [module.spoke_dns[0].inbound_endpoint_ip] : var.firewall.enabled ? [module.hub.firewall_private_ip] : []
  hub_dns_servers      = var.dns_servers != null ? var.dns_servers : (var.spoke_dns) ? [module.spoke_dns[0].inbound_endpoint_ip] : []

  spoke_dns_enabled = var.spoke_dns && var.address_space_spoke_dns != null

  p2s_certificate_enabled = var.virtual_network_gateway && var.p2s_vpn && contains(var.vpn_auth_types, "Certificate") && local.spoke_dns_enabled

  p2s_root_certificates = {}

  private_endpoint_zones = [
    "privatelink.blob.core.windows.net",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.monitor.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.vaultcore.azure.net",
    "privatelink.cognitiveservices.azure.com",
    "privatelink.openai.azure.com",
    "privatelink.azurewebsites.net",
    "privatelink.search.windows.net",
    "privatelink.${var.location}.azmk8s.io"
  ]
}

module "locations" {
  source   = "../base_modules/locations"
  location = var.location
}

module "hub" {
  source                       = "../pattern_hub"
  address_space                = var.address_space_hub
  bastion                      = var.bastion
  bastion_sku                  = var.bastion_sku
  dns_servers                  = local.hub_dns_servers
  environment                  = var.environment
  firewall                     = var.firewall
  virtual_network_gateway      = var.virtual_network_gateway
  virtual_network_gateway_sku  = var.virtual_network_gateway_sku
  virtual_network_gateway_type = var.virtual_network_gateway_type
  location                     = module.locations.name
  nat_gateway_public_ip_count  = var.nat_gateway_public_ip_count
  p2s_root_certificates        = local.p2s_root_certificates
  p2s_vpn                      = var.p2s_vpn
  deployment_token             = var.deployment_token
  storage_account              = true
  tags                         = local.tags
  vpn_auth_types               = var.vpn_auth_types
  workload                     = var.workload
}

module "spoke" {
  source                 = "../pattern_spoke"
  for_each               = { for spoke in var.address_space_spokes : "${spoke.workload}-${spoke.environment}-${spoke.instance}" => spoke }
  address_space          = each.value.address_space
  dependency_agent       = var.dependency_agent
  dns_servers            = local.vnet_dns_servers
  environment            = each.value.environment
  firewall               = var.firewall.enabled
  linux_virtual_machine  = each.value.virtual_machines
  location               = var.location
  monitor_agent          = var.private_monitoring
  network_security_group = var.network_security_group
  deployment_token       = var.deployment_token
  subnets_next_hop       = var.firewall.enabled ? module.hub.firewall_private_ip : null
  tags                   = local.tags
  update_management      = var.update_management
  watcher_agent          = var.connection_monitor
  workload               = each.value.workload
}

module "virtual_network_peerings" {
  source                                = "../base_modules/virtual_network_peerings"
  for_each                              = module.spoke
  virtual_network_1_resource_group_name = module.hub.resource_group_name
  virtual_network_1_id                  = module.hub.virtual_network_id
  virtual_network_1_hub                 = true
  virtual_network_2_resource_group_name = each.value.resource_group_name
  virtual_network_2_id                  = each.value.virtual_network_id
  gateway_exists                        = var.virtual_network_gateway

  depends_on = [
    module.hub,
    module.spoke
  ]
}

module "spoke_dns" {
  source                 = "../pattern_spoke_dns"
  count                  = (var.spoke_dns && var.address_space_spoke_dns != null) ? 1 : 0
  address_space          = var.address_space_spoke_dns
  default_next_hop       = (var.firewall.enabled) ? module.hub.firewall_private_ip : null
  environment            = var.environment
  location               = module.locations.name
  private_endpoint_zones = local.private_endpoint_zones
  deployment_token       = var.deployment_token
  tags                   = local.tags
}

module "virtual_network_peerings_dns" {
  source                                = "../base_modules/virtual_network_peerings"
  count                                 = (var.spoke_dns && var.address_space_spoke_dns != null) ? 1 : 0
  virtual_network_1_resource_group_name = module.hub.resource_group_name
  virtual_network_1_id                  = module.hub.virtual_network_id
  virtual_network_1_hub                 = true
  virtual_network_2_resource_group_name = module.spoke_dns[0].resource_group_name
  virtual_network_2_id                  = module.spoke_dns[0].virtual_network_id
  gateway_exists                        = var.virtual_network_gateway

  depends_on = [
    module.hub,
    module.spoke_dns
  ]
}

module "route_to_spoke_dns" {
  source                 = "../base_modules/route"
  count                  = (var.virtual_network_gateway && var.firewall.enabled && var.spoke_dns && var.address_space_spoke_dns != null) ? 1 : 0
  address_prefix         = module.spoke_dns[0].address_space[0]
  next_hop_in_ip_address = module.hub.firewall_private_ip
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = module.hub.resource_group_name
  route_table_name       = module.hub.gateway_route_table_name
}

module "route_to_spokes" {
  source                 = "../base_modules/route"
  for_each               = (var.virtual_network_gateway && var.firewall.enabled) ? { for spoke in var.address_space_spokes : "${spoke.workload}-${spoke.environment}-${spoke.instance}" => spoke } : {}
  address_prefix         = each.value.address_space[0]
  next_hop_in_ip_address = module.hub.firewall_private_ip
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = module.hub.resource_group_name
  route_table_name       = module.hub.gateway_route_table_name
}

module "pattern_monitoring" {
  source                     = "../pattern_monitoring"
  count                      = (var.private_monitoring && var.address_space_spoke_private_monitoring != null) ? 1 : 0
  address_space              = var.address_space_spoke_private_monitoring
  dns_servers                = local.vnet_dns_servers
  firewall_enabled           = var.firewall.enabled
  location                   = var.location
  log_analytics_workspace_id = module.hub.log_analytics_workspace_id
  next_hop                   = var.firewall.enabled ? module.hub.firewall_private_ip : ""
  deployment_token           = var.deployment_token
  private_dns_zone_ids = [
    module.spoke_dns[0].private_dns_zones["privatelink.monitor.azure.com"]["id"],
    module.spoke_dns[0].private_dns_zones["privatelink.agentsvc.azure-automation.net"]["id"],
    module.spoke_dns[0].private_dns_zones["privatelink.ods.opinsights.azure.com"]["id"],
    module.spoke_dns[0].private_dns_zones["privatelink.oms.opinsights.azure.com"]["id"],
    module.spoke_dns[0].private_dns_zones["privatelink.blob.core.windows.net"]["id"]
  ]
  tags = local.tags
}

module "virtual_network_peerings_monitoring" {
  source                                = "../base_modules/virtual_network_peerings"
  count                                 = (var.private_monitoring && var.address_space_spoke_private_monitoring != null) ? 1 : 0
  virtual_network_1_resource_group_name = module.hub.resource_group_name
  virtual_network_1_id                  = module.hub.virtual_network_id
  virtual_network_1_hub                 = true
  virtual_network_2_resource_group_name = module.pattern_monitoring[0].resource_group_name
  virtual_network_2_id                  = module.pattern_monitoring[0].virtual_network_id
  gateway_exists                        = var.virtual_network_gateway

  depends_on = [
    module.hub,
    module.pattern_monitoring
  ]
}

module "route_to_spoke_monitoring" {
  source                 = "../base_modules/route"
  count                  = (var.virtual_network_gateway && var.firewall.enabled && var.private_monitoring && var.address_space_spoke_private_monitoring != null) ? 1 : 0
  address_prefix         = var.address_space_spoke_private_monitoring[0]
  next_hop_in_ip_address = module.hub.firewall_private_ip
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = module.hub.resource_group_name
  route_table_name       = module.hub.gateway_route_table_name
}

module "data_collection_rule_association" {
  source                  = "../base_modules/monitor_data_collection_rule_association"
  for_each                = var.private_monitoring ? merge([for k, v in module.spoke : v.virtual_machines]...) : {}
  data_collection_rule_id = module.pattern_monitoring[0].monitor_data_collection_rule_id
  name                    = "${each.key}-dcra"
  target_resource_id      = each.value.id
}

module "data_collection_endpoint_association" {
  source                      = "../base_modules/monitor_data_collection_rule_association"
  for_each                    = var.private_monitoring ? merge([for k, v in module.spoke : v.virtual_machines]...) : {}
  data_collection_endpoint_id = module.pattern_monitoring[0].monitor_data_collection_endpoint_id
  target_resource_id          = each.value.id
}

data "azurerm_network_watcher" "this" {
  name                = "NetworkWatcher_${var.location}"
  resource_group_name = "NetworkWatcherRG"

  depends_on = [
    module.hub,
    module.spoke
  ]
}

resource "azurerm_network_connection_monitor" "external" {
  for_each           = var.connection_monitor ? merge([for k, v in module.spoke : v.virtual_machines]...) : {}
  location           = data.azurerm_network_watcher.this.location
  name               = "Monitor-Internet-${each.key}"
  network_watcher_id = data.azurerm_network_watcher.this.id

  endpoint {
    name               = each.key
    target_resource_id = each.value.id
  }

  endpoint {
    name    = "terraform-io"
    address = "terraform.io"
  }

  endpoint {
    name    = "ifconfig-me"
    address = "ifconfig.me"
  }

  test_configuration {
    name                      = "HttpTestConfiguration"
    protocol                  = "Http"
    test_frequency_in_seconds = 60

    http_configuration {
      port                     = 80
      valid_status_code_ranges = ["200-399"]
    }
  }

  test_configuration {
    name                      = "TCP443TestConfiguration"
    protocol                  = "Tcp"
    test_frequency_in_seconds = 60

    tcp_configuration {
      port = 443
    }
  }

  test_group {
    name                     = "Monitor-Internet-${each.key}"
    destination_endpoints    = ["ifconfig-me", "terraform-io"]
    source_endpoints         = [each.key]
    test_configuration_names = ["HttpTestConfiguration", "TCP443TestConfiguration"]
  }

  output_workspace_resource_ids = [module.hub.log_analytics_workspace_id]
}

resource "azurerm_network_connection_monitor" "internal" {
  count              = (var.connection_monitor && length(local.virtual_machines) >= 2) ? 1 : 0
  name               = "Monitor-Private"
  network_watcher_id = data.azurerm_network_watcher.this.id
  location           = data.azurerm_network_watcher.this.location

  dynamic "endpoint" {
    for_each = local.virtual_machines
    content {
      name               = endpoint.key
      target_resource_id = endpoint.value.id
    }
  }

  test_configuration {
    name                      = "IcmpTestConfiguration"
    protocol                  = "Icmp"
    test_frequency_in_seconds = 60
  }

  test_group {
    name                     = "Monitor-Private"
    destination_endpoints    = [for k, v in local.virtual_machines : k]
    source_endpoints         = [for k, v in local.virtual_machines : k]
    test_configuration_names = ["IcmpTestConfiguration"]
  }

  output_workspace_resource_ids = [module.hub.log_analytics_workspace_id]
}

resource "azurerm_network_watcher_flow_log" "this" {
  for_each             = var.network_security_group ? module.spoke : {}
  network_watcher_name = data.azurerm_network_watcher.this.name
  resource_group_name  = data.azurerm_network_watcher.this.resource_group_name
  name                 = "vnet-flowlog-${each.key}"

  target_resource_id = each.value.virtual_network_id
  storage_account_id = module.hub.storage_account_id
  enabled            = true
  version            = 2

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = module.hub.log_analytics_workspace_workspace_id
    workspace_region      = var.location
    workspace_resource_id = module.hub.log_analytics_workspace_id
    interval_in_minutes   = 10
  }
}

resource "azurerm_network_watcher_flow_log" "hub" {
  count                = var.network_security_group ? 1 : 0
  network_watcher_name = data.azurerm_network_watcher.this.name
  resource_group_name  = data.azurerm_network_watcher.this.resource_group_name
  name                 = "vnet-flowlog-${module.hub.virtual_network_name}"

  target_resource_id = module.hub.virtual_network_id
  storage_account_id = module.hub.storage_account_id
  enabled            = true
  version            = 2

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = module.hub.log_analytics_workspace_workspace_id
    workspace_region      = var.location
    workspace_resource_id = module.hub.log_analytics_workspace_id
    interval_in_minutes   = 10
  }
}

module "private_key_vault" {
  source = "../composite_modules/private_key_vault"
  count  = local.spoke_dns_enabled ? 1 : 0

  enabled_for_deployment                 = true
  enabled_for_disk_encryption            = true
  enabled_for_template_deployment        = true
  environment                            = var.environment
  instance                               = var.instance
  key_vault_private_dns_zone_resource_id = module.spoke_dns[0].private_dns_zones["privatelink.vaultcore.azure.net"]["id"]
  location                               = module.locations.name
  private_endpoint_subnet_resource_id    = module.hub.private_endpoint_subnet_id
  public_network_access_enabled          = false
  key_vault_administrators               = var.admin_object_ids
  deployment_token                       = var.deployment_token
  resource_group_name                    = module.hub.resource_group_management_name
  tags                                   = merge(local.tags, { "SecurityControl" : "Ignore" })
  tenant_id                              = var.tenant_id
  workload                               = var.workload
}

# module "p2s_root_certificate" {
#   source = "../composite_modules/p2s_root_certificate"
#   count  = local.p2s_certificate_enabled ? 1 : 0
#
#   environment  = var.environment
#   instance     = var.instance
#   key_vault_id = module.private_key_vault[0].id
#   tags         = local.tags
#   workload     = var.workload
# }
