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

  linux_virtual_machines = {
    for linux in module.linux_virtual_machine : linux.name => {
      id                        = linux.id
      admin_username            = linux.admin_username
      admin_password            = linux.admin_password
      source_image_reference_id = linux.source_image_reference_offer
      private_ip_address        = linux.private_ip_address
    }
  }

  virtual_machines = local.linux_virtual_machines
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

module "subnet" {
  source               = "../base_modules/subnet"
  random_string        = var.random_string
  count                = var.subnet_count
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  instance             = format("%03d", count.index + 1)
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [cidrsubnet(var.address_space[0], ceil(var.subnet_count / 2), count.index)]
}

module "network_security_group" {
  source              = "../base_modules/network_security_group"
  random_string       = var.random_string
  count               = var.network_security_group ? 1 : 0
  location            = var.location
  environment         = var.environment
  workload            = var.workload
  instance            = var.instance
  resource_group_name = module.resource_group.name
}

module "network_security_rules" {
  source                      = "../base_modules/network_security_rule"
  count                       = var.network_security_group ? length(var.network_security_rules) : 0
  name                        = var.network_security_rules[count.index].name
  priority                    = var.network_security_rules[count.index].priority
  direction                   = var.network_security_rules[count.index].direction
  access                      = var.network_security_rules[count.index].access
  protocol                    = var.network_security_rules[count.index].protocol
  source_port_range           = var.network_security_rules[count.index].source_port_range
  destination_port_range      = var.network_security_rules[count.index].destination_port_range
  source_address_prefix       = var.network_security_rules[count.index].source_address_prefix
  destination_address_prefix  = var.network_security_rules[count.index].destination_address_prefix
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.network_security_group[0].name
}

module "subnet_network_security_group_association" {
  source                    = "../base_modules/subnet_network_security_group_association"
  count                     = var.network_security_group ? var.subnet_count : 0
  network_security_group_id = module.network_security_group[0].id
  subnet_id                 = module.subnet[count.index].id
}

module "routing" {
  source              = "../pattern_routing"
  count               = (var.firewall) ? var.subnet_count : 0
  location            = var.location
  environment         = var.environment
  workload            = var.workload
  instance            = var.instance
  resource_group_name = module.resource_group.name
  next_hop            = var.subnets_next_hop
  next_hop_type       = "VirtualAppliance"
  subnet_id           = module.subnet[count.index].id
  tags                = local.tags
}

data "cloudinit_config" "nva" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      package_update  = true
      package_upgrade = true
      packages        = ["nginx"]

      write_files = [
        {
          path    = "/var/www/html/index.html"
          content = <<-EOT
            <!DOCTYPE html>
            <html>
            <head><title>NVA</title></head>
            <body><h1>Hello World from ${var.environment}-vm-${var.workload}-${var.instance}</h1></body>
            </html>
          EOT
        }
      ]

      runcmd = [
        "apt update -y && apt upgrade -y"
      ]
    })
  }
}

module "linux_virtual_machine" {
  source                = "../base_modules/linux_virtual_machine"
  random_string         = var.random_string
  count                 = var.linux_virtual_machine ? var.subnet_count : 0
  location              = var.location
  environment           = var.environment
  workload              = var.workload
  instance              = format("%03d", count.index + 1)
  resource_group_name   = module.resource_group.name
  subnet_id             = module.subnet[count.index].id
  monitor_agent         = var.monitor_agent
  dependency_agent      = var.dependency_agent
  watcher_agent         = var.watcher_agent
  identity_type         = var.monitor_agent ? "SystemAssigned" : "None"
  patch_mode            = var.update_management ? "AutomaticByPlatform" : "ImageDefault"
  patch_assessment_mode = var.update_management ? "AutomaticByPlatform" : "ImageDefault"
  custom_data           = data.cloudinit_config.nva.rendered
  tags                  = local.tags
}

module "maintenance_configuration" {
  source                 = "../base_modules/maintenance_configuration"
  random_string          = var.random_string
  count                  = (var.linux_virtual_machine && var.update_management) ? 1 : 0
  location               = var.location
  environment            = var.environment
  workload               = var.workload
  instance               = var.instance
  resource_group_name    = module.resource_group.name
  scope                  = "InGuestPatch"
  window_start_date_time = formatdate("YYYY-MM-DD 00:00", timestamp())
  tags                   = local.tags
}

resource "azurerm_maintenance_assignment_virtual_machine" "linux_virtual_machine" {
  count                        = (var.update_management && var.linux_virtual_machine) ? var.subnet_count : 0
  location                     = var.location
  maintenance_configuration_id = module.maintenance_configuration[0].id
  virtual_machine_id           = module.linux_virtual_machine[count.index].id
}