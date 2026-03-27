locals {
  module_tags = tomap(
    {
      terraform-azurerm-composable-level2 = "pattern_spoke"
    }
  )

  tags = merge(
    local.module_tags,
    var.tags
  )

  subnets = [
    {
      workload          = "aks-cluster",
      instance          = "001"
      delegation        = {}
      service_endpoints = ["Microsoft.KeyVault"]
    },
    {
      workload = "aks-lb",
      instance = "001"
      delegation = {
        "aks-delegation" = {
          name    = "Microsoft.ServiceNetworking/trafficControllers",
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }
      service_endpoints = []
    }
  ]
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

module "subnets" {
  source                               = "../base_modules/subnet"
  random_string                        = var.random_string
  for_each                             = { for i, subnet in local.subnets : subnet.workload => merge(subnet, { index = i }) }
  address_prefixes                     = [cidrsubnet(var.address_space[0], 2, each.value.index)]
  delegation                           = each.value.delegation
  environment                          = var.environment
  instance                             = format("%03d", each.value.instance)
  location                             = var.location
  resource_group_name                  = module.resource_group.name
  virtual_network_name                 = module.virtual_network.name
  snet_default_outbound_access_enabled = false
  service_endpoints                    = each.value.service_endpoints
  workload                             = each.value.workload
}

module "virtual_network_peerings" {
  source                                = "../base_modules/virtual_network_peerings"
  virtual_network_1_resource_group_name = var.hub_resource_group_name
  virtual_network_1_id                  = var.hub_virtual_network_id
  virtual_network_1_hub                 = true
  virtual_network_2_resource_group_name = module.resource_group.name
  virtual_network_2_id                  = module.virtual_network.id
  gateway_exists                        = var.gateway_exists
}

module "routing" {
  source              = "../pattern_routing"
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  next_hop            = var.subnets_next_hop
  next_hop_type       = "VirtualAppliance"
  random_string       = var.random_string
  resource_group_name = module.resource_group.name
  subnet_id           = module.subnets["aks-cluster"].id
  tags                = local.tags
  workload            = var.workload
}

module "network_security_group" {
  source              = "../base_modules/network_security_group"
  random_string       = var.random_string
  count               = var.network_security_group ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  resource_group_name = module.resource_group.name
  workload            = var.workload
}

module "network_security_rules" {
  source                      = "../base_modules/network_security_rule"
  count                       = var.network_security_group ? length(var.network_security_rules) : 0
  access                      = var.network_security_rules[count.index].access
  destination_address_prefix  = var.network_security_rules[count.index].destination_address_prefix
  destination_port_range      = var.network_security_rules[count.index].destination_port_range
  direction                   = var.network_security_rules[count.index].direction
  name                        = var.network_security_rules[count.index].name
  network_security_group_name = module.network_security_group[0].name
  priority                    = var.network_security_rules[count.index].priority
  protocol                    = var.network_security_rules[count.index].protocol
  resource_group_name         = module.resource_group.name
  source_address_prefix       = var.network_security_rules[count.index].source_address_prefix
  source_port_range           = var.network_security_rules[count.index].source_port_range
}

module "subnet_network_security_group_association" {
  source                    = "../base_modules/subnet_network_security_group_association"
  for_each                  = var.network_security_group ? module.subnets : {}
  network_security_group_id = module.network_security_group[0].id
  subnet_id                 = each.value.id
}

# TODO: This should be in a shared RG, not the AKS RG. 
module "acr" {
  source                     = "../base_modules/container_registry"
  random_string              = var.random_string
  environment                = var.environment
  instance                   = var.instance
  location                   = var.location
  log_analytics_workspace_id = var.log_analytics_workspace_id
  resource_group_name        = module.resource_group.name
  workload                   = var.workload
}

module "aks" {
  source                             = "../base_modules/kubernetes_services"
  admin_group_object_ids             = var.admin_group_object_ids
  aks_cluster_subnet                 = module.subnets["aks-cluster"].id
  aks_lb_snet                        = module.subnets["aks-lb"].id
  aks_vnet_id                        = module.virtual_network.id
  alert_email                        = var.alert_email
  application_gateway_for_containers = var.application_gateway_for_containers
  authorized_ip_ranges               = var.authorized_ip_ranges
  container_registry_id              = module.acr.id
  environment                        = var.environment
  instance                           = var.instance
  location                           = var.location
  log_analytics_workspace_id         = var.log_analytics_workspace_id
  monitor_workspace_id               = var.monitor_workspace_id
  outbound_type                      = "userDefinedRouting"
  random_string                      = var.random_string
  resource_group_name                = module.resource_group.name
  tenant_id                          = var.tenant_id
  vm_size                            = var.vm_size
  workload                           = var.workload
  workload_identity                  = true

  oidc_issuer_profile = {
    enabled = true
  }

  depends_on = [
    module.virtual_network_peerings,
    module.routing
  ]
}

module "key_vault" {
  source                        = "../base_modules/key_vault"
  random_string                 = var.random_string
  environment                   = var.environment
  instance                      = var.instance
  location                      = var.location
  resource_group_name           = module.resource_group.name
  tenant_id                     = var.tenant_id
  workload                      = var.workload
  public_network_access_enabled = true

  network_acls = [{
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.authorized_ip_ranges
    virtual_network_subnet_ids = [module.subnets["aks-cluster"].id]
  }]
}

resource "azurerm_role_assignment" "admin_keyvault_administrator" {
  for_each             = toset(var.admin_group_object_ids)
  principal_id         = each.value
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Administrator"
}

resource "azurerm_role_assignment" "alb_keyvault_secrets_user" {
  count                = var.application_gateway_for_containers ? 1 : 0
  principal_id         = module.aks.alb_identity_principal_id
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
}

resource "azurerm_role_assignment" "kubelet_keyvault_secrets_user" {
  principal_id         = module.aks.kubelet_identity_principal_id
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
}
