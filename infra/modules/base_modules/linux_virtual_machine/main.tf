locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "linux_virtual_machine",
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )

  ssh_algorithm = var.ssh_algorithm
  instance      = coalesce(var.instance, "001")
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurecaf_name" "vm" {
  name          = var.workload
  resource_type = "azurerm_linux_virtual_machine"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurecaf_name" "nic" {
  name          = var.workload
  resource_type = "azurerm_network_interface"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input = true
}

resource "azurerm_network_interface" "this" {
  name                           = coalesce(var.custom_network_interface_name, azurecaf_name.nic.result)
  location                       = module.locations.name
  resource_group_name            = var.resource_group_name
  ip_forwarding_enabled          = var.enable_ip_forwarding
  accelerated_networking_enabled = var.enable_accelerated_networking
  ip_configuration {
    name                          = var.ip_configuration_name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
    public_ip_address_id          = var.public_ip_address_id
  }
  tags = local.tags
}

resource "tls_private_key" "this" {
  algorithm = var.ssh_algorithm
}

resource "azurerm_linux_virtual_machine" "this" {
  name                            = coalesce(var.custom_name, azurecaf_name.vm.result)
  location                        = module.locations.name
  resource_group_name             = var.resource_group_name
  size                            = var.size
  zone                            = var.zone
  network_interface_ids           = [azurerm_network_interface.this.id]
  admin_username                  = var.admin_username
  disable_password_authentication = var.admin_password == "" ? true : false
  admin_password                  = var.admin_password == "" ? null : var.admin_password
  dynamic "admin_ssh_key" {
    for_each = var.admin_password == "" ? [1] : []
    content {
      username   = var.admin_username
      public_key = tls_private_key.this.public_key_openssh
    }
  }
  patch_mode                                             = var.patch_mode
  patch_assessment_mode                                  = var.patch_assessment_mode
  bypass_platform_safety_checks_on_user_schedule_enabled = var.patch_mode == "AutomaticByPlatform" ? true : false
  priority                                               = var.priority
  eviction_policy                                        = var.priority == "Spot" ? var.eviction_policy : null
  max_bid_price                                          = var.max_bid_price
  boot_diagnostics {}
  os_disk {
    name                 = coalesce(var.custom_os_disk_name, "${azurecaf_name.vm.result}-dsk")
    caching              = var.os_disk_caching
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size
  }
  source_image_reference {
    publisher = var.source_image_reference_publisher
    offer     = var.source_image_reference_offer
    sku       = var.source_image_reference_sku
    version   = var.source_image_reference_version
  }
  dynamic "plan" {
    for_each = var.plan_name != "" ? [1] : []
    content {
      name      = var.plan_name
      product   = var.plan_product
      publisher = var.plan_publisher
    }
  }
  dynamic "identity" {
    for_each = var.identity_type != "None" ? [1] : []
    content {
      type         = var.identity_type
      identity_ids = var.identity_ids
    }
  }
  custom_data = var.run_bootstrap ? coalesce(var.custom_data, base64encode("${path.module}/cloud-init.txt")) : null
  tags        = local.tags
}

module "monitor_agent" {
  source                     = "../virtual_machine_extension"
  count                      = var.monitor_agent ? 1 : 0
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = var.monitor_agent_publisher
  type                       = var.monitor_agent_type
  type_handler_version       = var.monitor_agent_type_handler_version
  automatic_upgrade_enabled  = var.monitor_agent_automatic_upgrade_enabled
  auto_upgrade_minor_version = var.monitor_agent_auto_upgrade_minor_version

  depends_on = [
    azurerm_linux_virtual_machine.this
  ]
}

module "dependency_agent" {
  source                     = "../virtual_machine_extension"
  count                      = var.dependency_agent ? 1 : 0
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = var.dependency_agent_publisher
  type                       = var.dependency_agent_type
  type_handler_version       = var.dependency_agent_type_handler_version
  automatic_upgrade_enabled  = var.dependency_agent_automatic_upgrade_enabled
  auto_upgrade_minor_version = var.dependency_agent_auto_upgrade_minor_version
  time_sleep                 = "10s"
  settings = jsonencode(
    {
      "enableAMA" = "true"
    }
  )

  depends_on = [
    module.monitor_agent
  ]
}

module "watcher_agent" {
  source                     = "../virtual_machine_extension"
  count                      = var.watcher_agent ? 1 : 0
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = var.watcher_agent_publisher
  type                       = var.watcher_agent_type
  type_handler_version       = var.watcher_agent_type_handler_version
  automatic_upgrade_enabled  = var.watcher_agent_automatic_upgrade_enabled
  auto_upgrade_minor_version = var.watcher_agent_auto_upgrade_minor_version

  depends_on = [
    azurerm_linux_virtual_machine.this
  ]
}

module "agents" {
  source                     = "../virtual_machine_extension"
  for_each                   = var.agents
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = each.value.publisher
  type                       = each.value.type
  type_handler_version       = each.value.type_handler_version
  automatic_upgrade_enabled  = each.value.automatic_upgrade_enabled
  auto_upgrade_minor_version = each.value.auto_upgrade_minor_version
  settings                   = each.value.settings

  depends_on = [
    azurerm_linux_virtual_machine.this
  ]
}
