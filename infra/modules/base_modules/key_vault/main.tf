locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "key_vault"
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
  resource_type = "azurerm_key_vault"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurerm_key_vault" "this" {
  name = coalesce(var.custom_name, azurecaf_name.this.result)

  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  location                        = module.locations.name
  public_network_access_enabled   = var.public_network_access_enabled
  purge_protection_enabled        = var.purge_protection_enabled
  rbac_authorization_enabled      = true
  resource_group_name             = var.resource_group_name
  sku_name                        = var.sku_name
  soft_delete_retention_days      = var.soft_delete_retention_days
  tags                            = local.tags

  dynamic "access_policy" {
    for_each = var.access_policy
    content {
      tenant_id = access_policy.value.tenant_id
      object_id = access_policy.value.object_id
      key_permissions = [
        for key_permission in access_policy.value.key_permissions : key_permission
      ]
      secret_permissions = [
        for secret_permission in access_policy.value.secret_permissions : secret_permission
      ]
      certificate_permissions = [
        for certificate_permission in access_policy.value.certificate_permissions : certificate_permission
      ]
      storage_permissions = [
        for storage_permission in access_policy.value.storage_permissions : storage_permission
      ]
    }
  }

  dynamic "network_acls" {
    for_each = var.network_acls
    content {
      bypass                     = network_acls.value.bypass
      default_action             = network_acls.value.default_action
      ip_rules                   = network_acls.value.ip_rules
      virtual_network_subnet_ids = network_acls.value.virtual_network_subnet_ids
    }
  }

  tenant_id = var.tenant_id
}
