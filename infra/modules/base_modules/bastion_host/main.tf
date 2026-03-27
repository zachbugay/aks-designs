locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "resource_group"
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

resource "azurecaf_name" "this" {
  name          = var.workload
  resource_type = "azurerm_bastion_host"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurerm_bastion_host" "this" {
  name                   = coalesce(var.custom_name, azurecaf_name.this.result)
  location               = module.locations.location.name
  resource_group_name    = var.resource_group_name
  sku                    = var.sku
  copy_paste_enabled     = var.copy_paste_enabled
  file_copy_enabled      = var.file_copy_enabled
  ip_connect_enabled     = var.ip_connect_enabled
  scale_units            = var.scale_units
  shareable_link_enabled = var.shareable_link_enabled
  tunneling_enabled      = var.tunneling_enabled
  virtual_network_id     = var.virtual_network_id
  dynamic "ip_configuration" {
    for_each = var.sku != "Developer" ? [1] : []
    content {
      name                 = var.ip_configuration_name
      subnet_id            = var.subnet_id
      public_ip_address_id = var.public_ip_address_id
    }
  }
  tags = local.tags
}
