locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "private_dns_resolver_dns_forwarding_ruleset"
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )
  instance = coalesce(var.instance, "001")
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurecaf_name" "this" {
  name          = var.workload
  resource_type = "azurerm_private_dns_resolver_dns_forwarding_ruleset"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurecaf_name" "vnet_link" {
  name          = var.workload
  resource_type = "azurerm_private_dns_resolver_virtual_network_link"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "this" {
  name                                       = coalesce(var.custom_name, azurecaf_name.this.result)
  location                                   = module.locations.name
  resource_group_name                        = var.resource_group_name
  private_dns_resolver_outbound_endpoint_ids = var.private_dns_resolver_outbound_endpoint_ids
  tags                                       = local.tags
}

resource "azurerm_private_dns_resolver_virtual_network_link" "this" {
  name                      = coalesce(var.custom_name_link, azurecaf_name.vnet_link.result)
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
  virtual_network_id        = var.virtual_network_id
}
