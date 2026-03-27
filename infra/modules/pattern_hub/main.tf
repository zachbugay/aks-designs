locals {
  public_ip_gateway_count = var.gateway ? 1 + (var.gateway_active_active ? 1 : 0) + (var.p2s_vpn ? 1 : 0) : 0

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
  #   5 → /27 (32 IPs)    – sufficient for gateway and app gateway subnets
  #   4 → /26 (64 IPs)    – required minimum for firewall and bastion subnets
  #
  # Layout (for 10.100.0.0/22):
  #   [0] GatewaySubnet                  /27  10.100.0.0/27
  #   [1] ApplicationGatewaySubnet       /27  10.100.0.32/27
  #   [2] AzureFirewallSubnet            /26  10.100.0.64/26
  #   [3] AzureFirewallManagementSubnet  /26  10.100.0.128/26
  #   [4] AzureBastionSubnet             /26  10.100.0.192/26
  hub_subnets = cidrsubnets(var.address_space[0], 5, 5, 4, 4, 4)
}

module "resource_group" {
  source        = "../base_modules/resource_group"
  random_string = var.random_string
  location      = var.location
  environment   = var.environment
  workload      = var.workload
  instance      = var.instance
  tags          = local.tags
}

module "resource_group_management" {
  source        = "../base_modules/resource_group"
  random_string = var.random_string
  location      = var.location
  environment   = var.environment
  workload      = var.workload_management
  instance      = var.instance
  tags          = local.tags
}

module "log_analytics_workspace" {
  source              = "../base_modules/log_analytics_workspace"
  random_string       = var.random_string
  location            = var.location
  environment         = var.environment
  workload            = var.workload_management
  instance            = var.instance
  resource_group_name = module.resource_group_management.name
  tags                = local.tags
}

module "monitor_workspace" {
  source              = "../base_modules/monitor_workspace"
  random_string       = var.random_string
  location            = var.location
  environment         = var.environment
  workload            = var.workload_management
  instance            = var.instance
  resource_group_name = module.resource_group_management.name
  tags                = local.tags
}

module "virtual_network" {
  source              = "../base_modules/virtual_network"
  random_string       = var.random_string
  location            = var.location
  environment         = var.environment
  workload            = var.workload
  instance            = var.instance
  resource_group_name = module.resource_group.name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = local.tags
}

module "subnet_gateway" {
  source               = "../base_modules/subnet"
  random_string        = var.random_string
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  custom_name          = "GatewaySubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [local.hub_subnets[0]]
}

module "subnet_firewall" {
  source               = "../base_modules/subnet"
  random_string        = var.random_string
  count                = var.firewall ? 1 : 0
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  custom_name          = "AzureFirewallSubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [local.hub_subnets[2]]
}

module "subnet_firewall_management" {
  source               = "../base_modules/subnet"
  random_string        = var.random_string
  count                = (var.firewall && var.firewall_sku_tier == "Basic") ? 1 : 0
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  custom_name          = "AzureFirewallManagementSubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [local.hub_subnets[3]]
}

module "subnet_bastion" {
  source               = "../base_modules/subnet"
  random_string        = var.random_string
  count                = var.bastion ? 1 : 0
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  custom_name          = "AzureBastionSubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [local.hub_subnets[4]]
}

module "public_ip_gateway" {
  source              = "../base_modules/public_ip"
  random_string       = var.random_string
  count               = local.public_ip_gateway_count
  location            = var.location
  environment         = var.environment
  workload            = "vgw"
  instance            = "00${count.index + 1}"
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "virtual_network_gateway" {
  source              = "../base_modules/virtual_network_gateway"
  random_string       = var.random_string
  count               = (var.gateway) ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = var.workload
  instance            = var.instance
  resource_group_name = module.resource_group.name
  type                = var.gateway_type
  sku                 = var.gateway_sku
  asn                 = var.asn
  active_active       = var.gateway_active_active
  p2s_vpn             = var.p2s_vpn
  ip_configurations = [for index, pip in module.public_ip_gateway : {
    name                 = "ipconfig${index + 1}"
    public_ip_address_id = pip.id
    subnet_id            = module.subnet_gateway.id
  }]
  tags = local.tags
}

module "route_table_gateway" {
  source              = "../base_modules/route_table"
  random_string       = var.random_string
  location            = var.location
  environment         = var.environment
  workload            = "vgw"
  instance            = var.instance
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
  random_string       = var.random_string
  count               = var.firewall ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = "fw"
  instance            = var.instance
  resource_group_name = module.resource_group.name
  zones               = ["1", "2", "3", "4"]
  tags                = local.tags
}

module "public_ip_firewall_management" {
  source              = "../base_modules/public_ip"
  random_string       = var.random_string
  count               = (var.firewall && var.firewall_sku_tier == "Basic") ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = "fw-mgmt"
  instance            = var.instance
  resource_group_name = module.resource_group.name
  zones               = ["1", "2", "3", "4"]
  tags                = local.tags
}

module "firewall_policy" {
  source              = "../base_modules/firewall_policy"
  random_string       = var.random_string
  count               = var.firewall ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = var.workload
  instance            = var.instance
  resource_group_name = module.resource_group.name
  sku                 = var.firewall_sku_tier
  dns_servers         = var.firewall_sku_tier != "Basic" ? var.dns_servers : null
  dns_proxy_enabled   = var.firewall_sku_tier != "Basic" && var.dns_servers != [] ? true : false
  tags                = local.tags
}

module "firewall" {
  source                     = "../base_modules/firewall"
  random_string              = var.random_string
  count                      = var.firewall ? 1 : 0
  location                   = var.location
  environment                = var.environment
  workload                   = var.workload
  instance                   = var.instance
  resource_group_name        = module.resource_group.name
  firewall_policy_id         = module.firewall_policy[0].id
  public_ip_address_id       = module.public_ip_firewall[0].id
  subnet_id                  = module.subnet_firewall[0].id
  log_analytics_workspace_id = module.log_analytics_workspace.id
  sku_tier                   = var.firewall_sku_tier
  zones                      = ["1", "2", "3"]
  management_ip_configuration = var.firewall_sku_tier == "Basic" ? {
    name                 = "mgmt-ipconfig"
    subnet_id            = module.subnet_firewall_management[0].id
    public_ip_address_id = module.public_ip_firewall_management[0].id
  } : null
  tags = local.tags
}

module "firewall_diagnostic_setting" {
  source                     = "../base_modules/monitor_diagnostic_setting"
  count                      = var.firewall ? 1 : 0
  target_resource_id         = module.firewall[0].id
  log_analytics_workspace_id = module.log_analytics_workspace.id
}

module "firewall_workbook" {
  source              = "../base_modules/firewall_workbook"
  random_string       = var.random_string
  count               = var.firewall ? 1 : 0
  location            = var.location
  environment         = var.environment
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  count              = (var.firewall && var.firewall_default_rules) ? 1 : 0
  name               = "default-rules"
  firewall_policy_id = module.firewall_policy[0].id
  priority           = 100

  network_rule_collection {
    name     = "internal"
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
    name     = "web"
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
    name     = "admin"
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
    name     = "aks"
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
    for_each = var.firewall_sku_tier != "Basic" ? [1] : []
    content {
      name     = "aks-fqdn"
      priority = 500
      action   = "Allow"
      rule {
        name                  = "aks-service-fqdn"
        source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
        destination_fqdn_tags = ["AzureKubernetesService"]
      }
    }
  }
}

module "public_ip_bastion" {
  source              = "../base_modules/public_ip"
  random_string       = var.random_string
  count               = var.bastion ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = "bas"
  instance            = var.instance
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "bastion_host" {
  source               = "../base_modules/bastion_host"
  random_string        = var.random_string
  count                = var.bastion ? 1 : 0
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  instance             = var.instance
  resource_group_name  = module.resource_group.name
  public_ip_address_id = module.public_ip_bastion[0].id
  subnet_id            = module.subnet_bastion[0].id
  sku                  = var.bastion_sku
  tags                 = local.tags
}

module "bastion_diagnostic_setting" {
  source                     = "../base_modules/monitor_diagnostic_setting"
  count                      = var.bastion ? 1 : 0
  target_resource_id         = module.bastion_host[0].id
  log_analytics_workspace_id = module.log_analytics_workspace.id
}

module "subnet_appgw" {
  source               = "../base_modules/subnet"
  random_string        = var.random_string
  count                = var.application_gateway ? 1 : 0
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  custom_name          = "ApplicationGatewaySubnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [local.hub_subnets[1]]
}

module "nsg_appgw" {
  source              = "../base_modules/network_security_group"
  random_string       = var.random_string
  count               = var.application_gateway ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = "appgw"
  instance            = var.instance
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "appgw_allow_gateway_manager" {
  count                       = var.application_gateway ? 1 : 0
  name                        = "AllowGatewayManager"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.nsg_appgw[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_http" {
  count                       = var.application_gateway ? 1 : 0
  name                        = "AllowHTTP"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.nsg_appgw[0].name
}

resource "azurerm_network_security_rule" "appgw_allow_https" {
  count                       = var.application_gateway ? 1 : 0
  name                        = "AllowHTTPS"
  priority                    = 210
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.nsg_appgw[0].name
}

module "subnet_nsg_association_appgw" {
  source                    = "../base_modules/subnet_network_security_group_association"
  count                     = var.application_gateway ? 1 : 0
  subnet_id                 = module.subnet_appgw[0].id
  network_security_group_id = module.nsg_appgw[0].id
}

module "public_ip_appgw" {
  source              = "../base_modules/public_ip"
  random_string       = var.random_string
  count               = var.application_gateway ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = "appgw"
  instance            = var.instance
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "application_gateway" {
  source               = "../base_modules/application_gateway"
  random_string        = var.random_string
  count                = var.application_gateway ? 1 : 0
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  instance             = var.instance
  resource_group_name  = module.resource_group.name
  subnet_id            = module.subnet_appgw[0].id
  public_ip_address_id = module.public_ip_appgw[0].id
  backend_ip_addresses = var.appgw_backend_ip_addresses
  waf_enabled          = var.appgw_waf_enabled
  waf_mode             = var.appgw_waf_mode
  tags                 = local.tags
}

module "public_ip_nat_gateway" {
  source              = "../base_modules/public_ip"
  random_string       = var.random_string
  count               = var.nat_gateway_public_ip_count
  location            = var.location
  environment         = var.environment
  workload            = "ng"
  instance            = "00${count.index + 1}"
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "nat_gateway" {
  source              = "../base_modules/nat_gateway"
  random_string       = var.random_string
  count               = var.nat_gateway_public_ip_count > 0 ? 1 : 0
  location            = var.location
  environment         = var.environment
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
  count          = (var.firewall && var.nat_gateway_public_ip_count > 0) ? 1 : 0
  subnet_id      = module.subnet_firewall[0].id
  nat_gateway_id = module.nat_gateway[0].id
}

module "storage_account" {
  count                        = var.storage_account ? 1 : 0
  source                       = "../base_modules/storage_account"
  random_string                = var.random_string
  location                     = var.location
  environment                  = var.environment
  workload                     = var.workload_management
  resource_group_name          = module.resource_group_management.name
  network_rules_default_action = "Deny"
  network_rules_bypass         = ["AzureServices"]
  network_rules_ip_rules       = []
  tags                         = local.tags
}
