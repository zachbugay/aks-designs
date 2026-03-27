locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "firewall_workbook"
    }
  )

  tags = merge(
    local.module_tags,
    var.tags
  )

  instance = coalesce(var.instance, "001")
}

module "locations" {
  source   = "../locations"
  location = var.location
}

data "http" "firewall_workbook" {
  url = var.url
}

resource "random_uuid" "this" {
}

resource "azurerm_application_insights_workbook" "this" {
  name                = random_uuid.this.result
  resource_group_name = var.resource_group_name
  location            = module.locations.name
  display_name        = var.display_name
  data_json           = data.http.firewall_workbook.response_body
  tags                = local.tags
}