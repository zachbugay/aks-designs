locals {
  module_tags = tomap(
    {
      terraform-azurerm-composable-level2 = "pattern_spoke_dns"
    }
  )

  tags = merge(
    local.module_tags,
    var.tags
  )
}

module "resource_group" {
  source        = "../base_modules/resource_group"
  deployment_token = var.deployment_token
  location      = var.location
  environment   = var.environment
  workload      = var.workload
  instance      = var.instance
  tags          = local.tags
}

module "virtual_network" {
  source              = "../base_modules/virtual_network"
  deployment_token       = var.deployment_token
  location            = var.location
  workload            = var.workload
  instance            = var.instance
  environment         = var.environment
  resource_group_name = module.resource_group.name
  address_space       = var.address_space
  tags                = local.tags
}

module "subnet_inbound" {
  source               = "../base_modules/subnet"
  deployment_token        = var.deployment_token
  location             = var.location
  environment          = var.environment
  workload             = "in"
  instance             = var.instance
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [cidrsubnet(var.address_space[0], 1, 0)]
  delegation = {
    "Microsoft.Network.dnsResolvers" = {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

module "routing_inbound" {
  source              = "../pattern_routing"
  deployment_token       = var.deployment_token
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  next_hop            = var.default_next_hop
  next_hop_type       = var.default_next_hop_type
  resource_group_name = module.resource_group.name
  subnet_id           = module.subnet_inbound.id
  tags                = local.tags
  workload            = "in"

  depends_on = [module.private_dns_resolver]
}

module "subnet_outbound" {
  source               = "../base_modules/subnet"
  address_prefixes     = [cidrsubnet(var.address_space[0], 1, 1)]
  environment          = var.environment
  instance             = var.instance
  location             = var.location
  deployment_token        = var.deployment_token
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  workload             = "out"
  delegation = {
    "Microsoft.Network.dnsResolvers" = {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

module "routing_outbound" {
  source              = "../pattern_routing"
  deployment_token       = var.deployment_token
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  next_hop            = var.default_next_hop
  next_hop_type       = var.default_next_hop_type
  resource_group_name = module.resource_group.name
  subnet_id           = module.subnet_outbound.id
  tags                = local.tags
  workload            = "out"

  depends_on = [module.private_dns_resolver]
}

module "private_dns_resolver" {
  source                      = "../base_modules/private_dns_resolver"
  deployment_token               = var.deployment_token
  location                    = var.location
  environment                 = var.environment
  workload                    = var.workload
  instance                    = var.instance
  resource_group_name         = module.resource_group.name
  virtual_network_id          = module.virtual_network.id
  inbound_endpoint_subnet_id  = module.subnet_inbound.id
  outbound_endpoint_subnet_id = module.subnet_outbound.id
  tags                        = local.tags

  depends_on = [module.private_dns_zones]
}

module "private_dns_resolver_dns_forwarding_ruleset" {
  source                                     = "../base_modules/private_dns_resolver_dns_forwarding_ruleset"
  deployment_token                              = var.deployment_token
  location                                   = var.location
  environment                                = var.environment
  workload                                   = var.workload
  instance                                   = var.instance
  resource_group_name                        = module.resource_group.name
  private_dns_resolver_outbound_endpoint_ids = [module.private_dns_resolver.outbound_endpoint_id]
  virtual_network_id                         = module.virtual_network.id
  tags                                       = local.tags

  depends_on = [
    module.private_dns_resolver,
    module.routing_inbound,
    module.routing_outbound
  ]
}

module "private_dns_resolver_forwarding_rules" {
  source                    = "../base_modules/private_dns_resolver_forwarding_rule"
  for_each                  = { for rule in var.dns_forwarding_rules : rule.domain_name => rule }
  dns_forwarding_ruleset_id = module.private_dns_resolver_dns_forwarding_ruleset.id
  domain_name               = each.value.domain_name
  target_dns_servers        = each.value.target_dns_servers
}

module "private_dns_zones" {
  source               = "../base_modules/private_dns_zone"
  for_each             = toset(var.private_endpoint_zones)
  name                 = each.value
  resource_group_name  = module.resource_group.name
  virtual_network_link = true
  virtual_network_id   = module.virtual_network.id
  tags                 = local.tags
}
