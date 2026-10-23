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
  # https://github.com/hashicorp/terraform/issues/23785
  test = pathexpand("~/${path.module}/main.tf")

  workspace           = split("/", var.log_analytics_workspace_id)
  subscription_id     = local.workspace[2]
  resource_group_name = local.workspace[4]
  workspace_name      = local.workspace[8]

  endpoint_check = "az monitor data-collection endpoint show --ids '${azurerm_monitor_data_collection_endpoint.this.id}' --query provisioningState --output tsv --only-show-errors"
  tables_check = join(" ", [
    "az monitor log-analytics workspace table list",
    "--subscription '${local.subscription_id}'",
    "--resource-group '${local.resource_group_name}'",
    "--workspace-name '${local.workspace_name}'",
    "--query \"length([?(name=='Syslog' || name=='InsightsMetrics') && provisioningState=='Succeeded'])\"",
    "--output tsv --only-show-errors",
  ])

  command_map = substr(local.test, 0, 1) == "/" ? {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      
      max_attempts=30
      
      for ((i = 1; i <= $max_attempts; i++)); do
        state=$(${local.endpoint_check}) || exit $?
        ready=$(${local.tables_check}) || exit $?

        case "$state" in
          Failed|Canceled|Cancelled)
            echo "Endpoint entered terminal state: $state" >&2
            exit 1
            ;;
        esac

        if [[ "$state" == "Succeeded" && "$ready" == "2" ]]; then
          echo "Endpoint and required workspace tables are ready."
          exit 0
        fi

        echo "Waiting ($i/$max_attempts): endpoint=$state; ready tables=$ready/2."
        if ((i < $max_attempts)); then sleep 10; fi
      done

      echo "Readiness timed out: endpoint=$state; ready tables=$ready/2." >&2
      exit 1
    EOT
    } : {
    interpreter = ["pwsh", "-NoProfile", "-NoLogo", "-Command", ]
    command     = <<-EOT
      $maxAttempts = 30
      $ErrorActionPreference = 'Stop'

      for ($i = 1; $i -le $maxAttempts; $i++) {
        $state = ${local.endpoint_check}
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        $ready = ${local.tables_check}
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        if ($state -in @('Failed', 'Canceled', 'Cancelled')) {
          throw "Endpoint entered terminal state: $state"
        }

        if ($state -eq 'Succeeded' -and $ready -eq '2') {
          Write-Host 'Endpoint and required workspace tables are ready.'
          exit 0
        }

        Write-Host "Waiting ($i/$maxAttempts): endpoint=$state; ready tables=$ready/2."
        if ($i -lt $maxAttempts) { Start-Sleep -Seconds 10 }
      }

      throw "Readiness timed out: endpoint=$state; ready tables=$ready/2."
    EOT
  }
}

module "locations" {
  source   = "../base_modules/locations"
  location = var.location
}

module "resource_group" {
  source           = "../base_modules/resource_group"
  deployment_token = var.deployment_token
  location         = var.location
  environment      = var.environment
  workload         = var.workload
  instance         = var.instance
  tags             = local.tags
}

module "virtual_network" {
  source              = "../base_modules/virtual_network"
  deployment_token    = var.deployment_token
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
  deployment_token     = var.deployment_token
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
  count               = var.firewall_enabled ? 1 : 0
  deployment_token    = var.deployment_token
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
  suffixes      = var.deployment_token != "" ? [var.deployment_token, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_monitor_data_collection_rule" "this" {
  name                        = azurecaf_name.data_collection_rule.result
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  kind                        = "Linux"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.this.id

  depends_on = [
    terraform_data.wait_for_monitoring_ready,
  ]

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
  suffixes      = var.deployment_token != "" ? [var.deployment_token, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurerm_monitor_data_collection_endpoint" "this" {
  name                          = azurecaf_name.data_collection_endpoint.result
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  public_network_access_enabled = false
}

# DCE is Data Collection Endpoint.
resource "terraform_data" "wait_for_monitoring_ready" {
  triggers_replace = [
    azurerm_monitor_data_collection_endpoint.this.id,
    var.log_analytics_workspace_id,
    sha256(local.command_map.command),
  ]

  provisioner "local-exec" {
    interpreter = local.command_map.interpreter
    command     = local.command_map.command
  }
}

resource "azurecaf_name" "private_link_scope" {
  name          = var.workload
  resource_type = "azurerm_monitor_private_link_scope"
  prefixes      = [var.environment]
  suffixes      = var.deployment_token != "" ? [var.deployment_token, local.instance] : [local.instance]
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
  suffixes      = var.deployment_token != "" ? [var.deployment_token, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurecaf_name" "nic" {
  name          = var.workload
  resource_type = "azurerm_public_ip"
  prefixes      = [var.environment]
  suffixes      = var.deployment_token != "" ? [var.deployment_token, local.instance] : [local.instance]
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

  depends_on = [
    module.routing,
  ]
}
