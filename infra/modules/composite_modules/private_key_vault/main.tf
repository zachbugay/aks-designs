locals {
  module_tags = tomap(
    {
      terraform-azurerm-composite = "private_key_vault"
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )

  instance = coalesce(var.instance, "001")

  # for_each keys must be known at plan time, so the managed identity uses a static
  # key while its principal_id stays unknown until apply.
  key_vault_administrators = merge(
    { for object_id in var.key_vault_administrators : object_id => object_id },
    { managed_identity = azurerm_user_assigned_identity.this.principal_id }
  )
}

module "locations" {
  source   = "../../base_modules/locations"
  location = var.location
}

module "key_vault" {
  source = "../../base_modules/key_vault"

  custom_name                     = var.custom_name
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  environment                     = var.environment
  instance                        = local.instance
  location                        = module.locations.name
  public_network_access_enabled   = var.public_network_access_enabled
  purge_protection_enabled        = var.purge_protection_enabled
  random_string                   = var.random_string
  rbac_authorization_enabled      = true
  resource_group_name             = var.resource_group_name
  sku_name                        = var.sku_name
  soft_delete_retention_days      = var.soft_delete_retention_days
  tags                            = local.tags
  tenant_id                       = var.tenant_id
  workload                        = var.workload

  network_acls = [{
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }]
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${module.key_vault.name}"
  location            = module.locations.name
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_resource_id
  tags                = local.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = "psc-${module.key_vault.name}"
    private_connection_resource_id = module.key_vault.id
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.key_vault_private_dns_zone_resource_id != null ? [1] : []
    content {
      name                 = "pdzg-${module.key_vault.name}"
      private_dns_zone_ids = [var.key_vault_private_dns_zone_resource_id]
    }
  }
}

resource "azurecaf_name" "managed_identity" {
  name          = "kv-${var.workload}"
  resource_type = "azurerm_user_assigned_identity"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_user_assigned_identity" "this" {
  name                = azurecaf_name.managed_identity.result
  location            = module.locations.name
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

resource "azurerm_role_assignment" "key_vault_administrators" {
  for_each             = local.key_vault_administrators
  principal_id         = each.value
  role_definition_name = "Key Vault Administrator"
  scope                = module.key_vault.id
}

