locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "private_dns_resolver"
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
  resource_type = "azurerm_private_dns_resolver"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurecaf_name" "in" {
  name          = var.workload
  resource_type = "azurerm_private_dns_resolver_inbound_endpoint"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurecaf_name" "out" {
  name          = var.workload
  resource_type = "azurerm_private_dns_resolver_outbound_endpoint"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurerm_private_dns_resolver" "this" {
  name                = coalesce(var.custom_name, azurecaf_name.this.result)
  location            = module.locations.name
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.virtual_network_id
  tags                = local.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  name                    = coalesce(var.custom_name_inbound_endpoint, azurecaf_name.in.result)
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = azurerm_private_dns_resolver.this.location
  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = var.inbound_endpoint_subnet_id
  }
  tags = local.tags
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  name                    = coalesce(var.custom_name_outbound_endpoint, azurecaf_name.out.result)
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = azurerm_private_dns_resolver.this.location
  subnet_id               = var.outbound_endpoint_subnet_id
  tags                    = local.tags
}
