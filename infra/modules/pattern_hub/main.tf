locals {
  public_ip_virtual_network_gateway_count = var.gateway ? 1 + (var.gateway_active_active ? 1 : 0) : 0

  module_tags = tomap(
    {
      terraform-azurerm-composable-level2 = "pattern_hub"
    }
  )

  tags = merge(
    local.module_tags,
    var.tags
  )
  # Hub VNet subnet allocation using cidrsubnets for variable-sized subnets.
  # For a /22 VNet, newbits values produce:
  #   5 -> /27 (32 IPs)    – sufficient for gateway and app gateway subnets
  #   4 -> /26 (64 IPs)    – required minimum for firewall and bastion subnets
  #
  # Layout (for 10.100.0.0/22):
  #   [0] GatewaySubnet                  /27  10.100.0.0/27
  #   [1] ApplicationGatewaySubnet       /27  10.100.0.32/27
  #   [2] AzureFirewallSubnet            /26  10.100.0.64/26
  #   [3] AzureFirewallManagementSubnet  /26  10.100.0.128/26
  #   [4] AzureBastionSubnet             /26  10.100.0.192/26
  #   [5] snet-private-endpoints         /26  10.100.1.0/26
  hub_subnets = cidrsubnets(var.address_space[0], 5, 5, 4, 4, 4, 4)
}

module "resource_group" {
  source        = "../base_modules/resource_group"
  environment   = var.environment
  instance      = var.instance
  location      = var.location
  random_string = var.random_string
  workload      = var.workload
  tags          = local.tags
}

module "resource_group_management" {
  source        = "../base_modules/resource_group"
  environment   = var.environment
  instance      = var.instance
  location      = var.location
  random_string = var.random_string
  workload      = var.workload_management
  tags          = local.tags
}

module "log_analytics_workspace" {
  source              = "../base_modules/log_analytics_workspace"
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = var.workload_management
  resource_group_name = module.resource_group_management.name
  tags                = local.tags
}

module "monitor_workspace" {
  source              = "../base_modules/monitor_workspace"
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = var.workload_management
  resource_group_name = module.resource_group_management.name
  tags                = local.tags
}

module "virtual_network" {
  source              = "../base_modules/virtual_network"
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = var.workload
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "subnet_gateway" {
  source               = "../base_modules/subnet"
  address_prefixes     = [local.hub_subnets[0]]
  custom_name          = "GatewaySubnet"
  environment          = var.environment
  location             = var.location
  random_string        = var.random_string
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  workload             = var.workload
}

module "subnet_firewall" {
  source               = "../base_modules/subnet"
  count                = var.firewall.enabled ? 1 : 0
  address_prefixes     = [local.hub_subnets[2]]
  custom_name          = "AzureFirewallSubnet"
  environment          = var.environment
  location             = var.location
  random_string        = var.random_string
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  workload             = var.workload
}

module "subnet_firewall_management" {
  source               = "../base_modules/subnet"
  count                = (var.firewall.enabled) ? 1 : 0
  address_prefixes     = [local.hub_subnets[3]]
  custom_name          = "AzureFirewallManagementSubnet"
  environment          = var.environment
  location             = var.location
  random_string        = var.random_string
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  workload             = var.workload
}

module "subnet_bastion" {
  source               = "../base_modules/subnet"
  count                = var.bastion ? 1 : 0
  address_prefixes     = [local.hub_subnets[4]]
  custom_name          = "AzureBastionSubnet"
  environment          = var.environment
  location             = var.location
  random_string        = var.random_string
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  workload             = var.workload
}

module "subnet_private_endpoints" {
  source               = "../base_modules/subnet"
  address_prefixes     = [local.hub_subnets[5]]
  custom_name          = "snet-private-endpoints"
  environment          = var.environment
  location             = var.location
  random_string        = var.random_string
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  workload             = var.workload
}

module "public_ip_virtual_network_gateway" {
  source              = "../base_modules/public_ip"
  count               = local.public_ip_virtual_network_gateway_count
  environment         = var.environment
  instance            = "00${count.index + 1}"
  location            = var.location
  random_string       = var.random_string
  resource_group_name = module.resource_group.name
  tags                = local.tags
  workload            = "vgw"
}

module "virtual_network_gateway" {
  source        = "../base_modules/virtual_network_gateway"
  count         = (var.gateway) ? 1 : 0
  active_active = var.gateway_active_active
  asn           = var.asn
  environment   = var.environment
  instance      = var.instance
  ip_configurations = [for index, pip in module.public_ip_virtual_network_gateway : {
    name                 = "ipconfig${index + 1}"
    public_ip_address_id = pip.id
    subnet_id            = module.subnet_gateway.id
  }]
  location              = var.location
  p2s_root_certificates = var.p2s_root_certificates
  p2s_vpn               = var.p2s_vpn
  random_string         = var.random_string
  resource_group_name   = module.resource_group.name
  sku                   = var.gateway_sku
  tags                  = local.tags
  type                  = var.gateway_type
  vpn_auth_types        = var.vpn_auth_types
  workload              = var.workload
}

module "route_table_gateway" {
  source              = "../base_modules/route_table"
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = "vgw"
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "subnet_route_table_association_gateway" {
  source         = "../base_modules/subnet_route_table_association"
  subnet_id      = module.subnet_gateway.id
  route_table_id = module.route_table_gateway.id
}

module "public_ip_firewall" {
  source              = "../base_modules/public_ip"
  count               = var.firewall.enabled ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = "fw"
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "public_ip_firewall_management" {
  source              = "../base_modules/public_ip"
  count               = (var.firewall.enabled) ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = "fw-mgmt"
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "firewall_policy" {
  source              = "../base_modules/firewall_policy"
  count               = var.firewall.enabled ? 1 : 0
  dns_proxy_enabled   = (var.dns_servers != []) ? true : false
  dns_servers         = var.dns_servers
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  sku                 = var.firewall.sku_tier
  workload            = var.workload
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "firewall" {
  source                     = "../base_modules/firewall"
  count                      = var.firewall.enabled ? 1 : 0
  environment                = var.environment
  firewall_policy_id         = module.firewall_policy[0].id
  instance                   = var.instance
  location                   = var.location
  log_analytics_workspace_id = module.log_analytics_workspace.id
  public_ip_address_id       = module.public_ip_firewall[0].id
  random_string              = var.random_string
  resource_group_name        = module.resource_group.name
  sku_tier                   = var.firewall.sku_tier
  subnet_id                  = module.subnet_firewall[0].id
  workload                   = var.workload
  management_ip_configuration = var.firewall.sku_tier == "Basic" ? {
    name                 = "mgmt-ipconfig"
    subnet_id            = module.subnet_firewall_management[0].id
    public_ip_address_id = module.public_ip_firewall_management[0].id
  } : null
  tags = local.tags
}

module "firewall_diagnostic_setting" {
  source                     = "../base_modules/monitor_diagnostic_setting"
  count                      = var.firewall.enabled ? 1 : 0
  target_resource_id         = module.firewall[0].id
  log_analytics_workspace_id = module.log_analytics_workspace.id
}

module "firewall_workbook" {
  source              = "../base_modules/firewall_workbook"
  random_string       = var.random_string
  count               = var.firewall.enabled ? 1 : 0
  location            = var.location
  environment         = var.environment
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  count              = (var.firewall.enabled) ? 1 : 0
  name               = "rcg-default-rules"
  firewall_policy_id = module.firewall_policy[0].id
  priority           = 100

  network_rule_collection {
    name     = "network_rule_collection_allow_internal"
    priority = 100
    action   = "Allow"
    rule {
      name                  = "private-private-any"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_ports     = ["*"]
    }
  }

  network_rule_collection {
    name     = "network_rule_collection_allow_internal_web"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "private-internet-web"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["80", "443"]
    }
  }

  network_rule_collection {
    name     = "network_rule_collection_allow_internal_admin"
    priority = 300
    action   = "Allow"
    rule {
      name                  = "private-azure-kms"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["20.118.99.224", "40.83.235.53"]
      destination_ports     = ["1688"]
    }
    rule {
      name                  = "private-azure-ntp"
      protocols             = ["UDP"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["51.145.123.29"]
      destination_ports     = ["123"]
    }
  }

  network_rule_collection {
    name     = "network_rule_collection_allow_internal_aks"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "aks-apiserver-tcp"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["9000", "443"]
    }
    rule {
      name                  = "aks-apiserver-udp"
      protocols             = ["UDP"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["1194"]
    }
  }

  dynamic "application_rule_collection" {
    for_each = var.firewall.sku_tier != "Basic" ? [1] : []
    content {
      name     = "application_rule_collection_aks_internal_fqdn"
      priority = 500
      action   = "Allow"
      rule {
        name                  = "aks-service-fqdn"
        source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
        destination_fqdn_tags = ["AzureKubernetesService"]
        protocols {
          type = "Http"
          port = 80
        }
        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}

module "public_ip_bastion" {
  source              = "../base_modules/public_ip"
  count               = var.bastion ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = "bas"
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "bastion_host" {
  source               = "../base_modules/bastion_host"
  count                = var.bastion ? 1 : 0
  environment          = var.environment
  instance             = var.instance
  location             = var.location
  public_ip_address_id = module.public_ip_bastion[0].id
  random_string        = var.random_string
  resource_group_name  = module.resource_group.name
  sku                  = var.bastion_sku
  subnet_id            = module.subnet_bastion[0].id
  tags                 = local.tags
  workload             = var.workload
}

module "bastion_diagnostic_setting" {
  source                     = "../base_modules/monitor_diagnostic_setting"
  count                      = var.bastion ? 1 : 0
  target_resource_id         = module.bastion_host[0].id
  log_analytics_workspace_id = module.log_analytics_workspace.id
}

module "subnet_appgw" {
  source               = "../base_modules/subnet"
  address_prefixes     = [local.hub_subnets[1]]
  count                = var.application_gateway ? 1 : 0
  custom_name          = "ApplicationGatewaySubnet"
  environment          = var.environment
  location             = var.location
  random_string        = var.random_string
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  workload             = var.workload
}

module "nsg_appgw" {
  source        = "../base_modules/network_security_group"
  count         = var.application_gateway ? 1 : 0
  environment   = var.environment
  instance      = var.instance
  location      = var.location
  random_string = var.random_string
  workload      = "appgw"

  resource_group_name = module.resource_group.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "appgw_allow_gateway_manager" {
  count                       = var.application_gateway ? 1 : 0
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "65200-65535"
  direction                   = "Inbound"
  name                        = "AllowGatewayManager"
  network_security_group_name = module.nsg_appgw[0].name
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = module.resource_group.name
  source_address_prefix       = "GatewayManager"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "appgw_allow_http" {
  count                       = var.application_gateway ? 1 : 0
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "80"
  direction                   = "Inbound"
  name                        = "AllowHTTP"
  network_security_group_name = module.nsg_appgw[0].name
  priority                    = 200
  protocol                    = "Tcp"
  resource_group_name         = module.resource_group.name
  source_address_prefix       = "Internet"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "appgw_allow_https" {
  count                       = var.application_gateway ? 1 : 0
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "443"
  direction                   = "Inbound"
  name                        = "AllowHTTPS"
  network_security_group_name = module.nsg_appgw[0].name
  priority                    = 210
  protocol                    = "Tcp"
  resource_group_name         = module.resource_group.name
  source_address_prefix       = "Internet"
  source_port_range           = "*"
}

module "subnet_nsg_association_appgw" {
  source                    = "../base_modules/subnet_network_security_group_association"
  count                     = var.application_gateway ? 1 : 0
  subnet_id                 = module.subnet_appgw[0].id
  network_security_group_id = module.nsg_appgw[0].id
}

module "public_ip_appgw" {
  source              = "../base_modules/public_ip"
  count               = var.application_gateway ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  workload            = "appgw"
  resource_group_name = module.resource_group.name
  tags                = local.tags

}

# module "application_gateway" {
#   source               = "../base_modules/application_gateway"
#   count                = var.application_gateway ? 1 : 0
#   backend_ip_addresses = var.appgw_backend_ip_addresses
#   environment          = var.environment
#   instance             = var.instance
#   location             = var.location
#   public_ip_address_id = module.public_ip_appgw[0].id
#   random_string        = var.random_string
#   resource_group_name  = module.resource_group.name
#   subnet_id            = module.subnet_appgw[0].id
#   tags                 = local.tags
#   waf_enabled          = var.appgw_waf_enabled
#   waf_mode             = var.appgw_waf_mode
#   workload             = var.workload
# }
#
module "public_ip_nat_gateway" {
  source              = "../base_modules/public_ip"
  count               = var.nat_gateway_public_ip_count
  environment         = var.environment
  instance            = "00${count.index + 1}"
  location            = var.location
  random_string       = var.random_string
  resource_group_name = module.resource_group.name
  tags                = local.tags
  workload            = "ng"
}

module "nat_gateway" {
  source              = "../base_modules/nat_gateway"
  count               = var.nat_gateway_public_ip_count > 0 ? 1 : 0
  environment         = var.environment
  location            = var.location
  random_string       = var.random_string
  sku                 = "Standard"
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count                = var.nat_gateway_public_ip_count
  nat_gateway_id       = module.nat_gateway[0].id
  public_ip_address_id = module.public_ip_nat_gateway[count.index].id
}

resource "azurerm_subnet_nat_gateway_association" "firewall_outbound" {
  count          = (var.firewall.enabled && var.nat_gateway_public_ip_count > 0) ? 1 : 0
  nat_gateway_id = module.nat_gateway[0].id
  subnet_id      = module.subnet_firewall[0].id
}

module "storage_account" {
  source                       = "../base_modules/storage_account"
  count                        = var.storage_account ? 1 : 0
  environment                  = var.environment
  location                     = var.location
  network_rules_bypass         = ["AzureServices"]
  network_rules_default_action = "Deny"
  network_rules_ip_rules       = []
  random_string                = var.random_string
  resource_group_name          = module.resource_group_management.name
  tags                         = local.tags
  workload                     = var.workload_management
}
