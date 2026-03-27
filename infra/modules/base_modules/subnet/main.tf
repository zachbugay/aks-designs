locals {
  instance = coalesce(var.instance, "001")
}

resource "azurecaf_name" "this" {
  name          = var.workload
  resource_type = "azurerm_subnet"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurerm_subnet" "this" {
  name                                          = coalesce(var.custom_name, azurecaf_name.this.result)
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = var.virtual_network_name
  address_prefixes                              = var.address_prefixes
  private_endpoint_network_policies             = var.private_endpoint_network_policies
  private_link_service_network_policies_enabled = var.private_link_service_network_policies_enabled
  service_endpoints                             = var.service_endpoints
  service_endpoint_policy_ids                   = var.service_endpoint_policy_ids
  default_outbound_access_enabled               = var.snet_default_outbound_access_enabled
  dynamic "delegation" {
    for_each = var.delegation
    content {
      name = delegation.key
      service_delegation {
        name    = delegation.value.name
        actions = delegation.value.actions
      }
    }
  }
}