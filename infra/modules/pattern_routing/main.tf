locals {
  module_tags = tomap(
    {
      terraform-azurerm-composable-level1 = "routing"
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )
}

module "route_table" {
  source                        = "../base_modules/route_table"
  random_string                 = var.random_string
  custom_name                   = var.custom_name
  location                      = var.location
  environment                   = var.environment
  workload                      = var.workload
  instance                      = var.instance
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = local.tags
}

module "route" {
  source                 = "../base_modules/route"
  resource_group_name    = var.resource_group_name
  route_table_name       = module.route_table.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = var.next_hop_type
  next_hop_in_ip_address = var.next_hop
}

module "subnet_route_table_association" {
  source         = "../base_modules/subnet_route_table_association"
  subnet_id      = var.subnet_id
  route_table_id = module.route_table.id
}
