locals {
  module_tags = tomap(
    {
      terraform-azurerm-composable-level2 = "pattern_monitoring"
    }
  )

  tags = merge(
    local.module_tags,
    var.tags
  )
  instance = coalesce(var.instance, "001")
}

module "locations" {
  source   = "../base_modules/locations"
  location = var.location
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
  location             = var.location
  environment          = var.environment
  workload             = var.workload
  instance             = var.instance
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = var.address_space
}

module "routing" {
  source              = "../pattern_routing"
  count               = var.firewall ? 1 : 0
  random_string       = var.random_string
  location            = var.location
  environment         = var.environment
  workload            = var.workload
  instance            = var.instance
  resource_group_name = module.resource_group.name
  next_hop            = var.next_hop
  next_hop_type       = "VirtualAppliance"
  subnet_id           = module.subnet.id
  tags                = local.tags
}

resource "azurecaf_name" "data_collection_rule" {
  name          = var.workload
  resource_type = "azurerm_monitor_data_collection_rule"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_monitor_data_collection_rule" "this" {
  name                        = azurecaf_name.data_collection_rule.result
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  kind                        = "Linux"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.this.id

  depends_on = [terraform_data.wait_for_dce_ready]

  destinations {
    log_analytics {
      name                  = "log_analytics"
      workspace_resource_id = var.log_analytics_workspace_id
    }
  }
  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-InsightsMetrics", "Microsoft-ServiceMap"]
    destinations = ["log_analytics"]
  }
  data_sources {
    syslog {
      name    = "Syslog"
      streams = ["Microsoft-Syslog"]
      facility_names = [
        "*"
      ]
      log_levels = [
        "Debug",
        "Info",
        "Notice",
        "Warning",
        "Error",
        "Critical",
        "Alert",
        "Emergency",
      ]
    }
    performance_counter {
      counter_specifiers = [
        "\\VmInsights\\DetailedMetrics"
      ]
      name                          = "VMInsightsPerfCounters"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-InsightsMetrics"]
    }
    extension {
      extension_name = "DependencyAgent"
      name           = "DependencyAgentDataSource"
      streams        = ["Microsoft-ServiceMap"]
    }
  }
}

resource "azurecaf_name" "data_collection_endpoint" {
  name          = var.workload
  resource_type = "azurerm_monitor_data_collection_endpoint"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_monitor_data_collection_endpoint" "this" {
  name                          = azurecaf_name.data_collection_endpoint.result
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  public_network_access_enabled = false
}

resource "terraform_data" "wait_for_dce_ready" {
  triggers_replace = [azurerm_monitor_data_collection_endpoint.this.id]
  # DCE is Data Collection Endpoint.
  provisioner "local-exec" {
    interpreter = ["pwsh", "-NoProfile", "-NoLogo", "-Command", ]
    command     = <<-EOT
      $maxAttempts = 30
      for ($i = 1; $i -le $maxAttempts; $i++) {
        $result = az monitor data-collection endpoint show --ids '${azurerm_monitor_data_collection_endpoint.this.id}' --query provisioningState -o tsv 2>$null
        if ($result -eq 'Succeeded') {
          Write-Host "Data Collection Endpoint is ready (provisioningState: Succeeded)."
          exit 0
        }
        Write-Host "Waiting for DCE to be ready... (attempt $i/$maxAttempts, provisioningState: $result)"
        Start-Sleep -Seconds 10
      }
      Write-Error "Data Collection Endpoint did not reach 'Succeeded' state within timeout."
      exit 1
    EOT
  }
}

resource "azurecaf_name" "private_link_scope" {
  name          = var.workload
  resource_type = "azurerm_monitor_private_link_scope"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_monitor_private_link_scope" "this" {
  name                = azurecaf_name.private_link_scope.result
  resource_group_name = module.resource_group.name
}

resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "law-${azurerm_monitor_private_link_scope.this.name}"
  resource_group_name = module.resource_group.name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = var.log_analytics_workspace_id
}

resource "azurerm_monitor_private_link_scoped_service" "mdce" {
  name                = "mdce-${azurerm_monitor_private_link_scope.this.name}"
  resource_group_name = module.resource_group.name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = azurerm_monitor_data_collection_endpoint.this.id
}

resource "azurecaf_name" "pe" {
  name          = var.workload
  resource_type = "azurerm_private_endpoint"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurecaf_name" "nic" {
  name          = var.workload
  resource_type = "azurerm_public_ip"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_private_endpoint" "this" {
  name                          = azurecaf_name.pe.result
  custom_network_interface_name = azurecaf_name.nic.result
  location                      = module.resource_group.location
  resource_group_name           = module.resource_group.name
  subnet_id                     = module.subnet.id

  private_service_connection {
    name                           = "psc-${azurerm_monitor_private_link_scope.this.name}"
    private_connection_resource_id = azurerm_monitor_private_link_scope.this.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-${azurerm_monitor_private_link_scope.this.name}"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
