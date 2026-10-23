locals {
  aks_cluster_name = azurerm_kubernetes_cluster.this.name

  # Data collection endpoint names are limited to 44 characters.
  msprom_data_collection_name_base = "MSProm-${module.locations.name}-${local.aks_cluster_name}"
  msprom_data_collection_name = (
    length(local.msprom_data_collection_name_base) <= 44 ? local.msprom_data_collection_name_base : format(
      "%s-%s",
      trimsuffix(substr(local.msprom_data_collection_name_base, 0, 35), "-"),
      substr(sha1(local.msprom_data_collection_name_base), 0, 8),
    )
  )

  container_insights_streams = [
    "Microsoft-ContainerLog",
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
    "Microsoft-KubeNodeInventory",
  ]

  metric_alerts = {
    cpu = {
      name        = "CPU Usage Percentage"
      metric_name = "node_cpu_usage_percentage"
      threshold   = 95
    }
    memory = {
      name        = "Memory Working Set Percentage"
      metric_name = "node_memory_working_set_percentage"
      threshold   = 100
    }
  }
}

resource "azurerm_monitor_data_collection_endpoint" "msprom" {
  name                = local.msprom_data_collection_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = module.locations.name
  kind                = "Linux"
  tags                = local.tags
}

resource "azurerm_monitor_data_collection_rule" "msprom" {
  name                        = local.msprom_data_collection_name
  resource_group_name         = data.azurerm_resource_group.rg.name
  location                    = module.locations.name
  kind                        = "Linux"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.msprom.id
  tags                        = local.tags

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = var.monitor_workspace_id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "msprom_dcr" {
  name                    = "dcr-${local.aks_cluster_name}"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.msprom.id
}

resource "azurerm_monitor_data_collection_rule_association" "msprom_dce" {
  name                        = "configurationAccessEndpoint"
  target_resource_id          = azurerm_kubernetes_cluster.this.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.msprom.id
}

resource "azurerm_monitor_data_collection_rule" "msci" {
  name                = "MSCI-${module.locations.name}-${local.aks_cluster_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = module.locations.name
  kind                = "Linux"
  tags                = local.tags

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = local.container_insights_streams
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }

  destinations {
    log_analytics {
      name                  = "ciworkspace"
      workspace_resource_id = var.log_analytics_workspace_id
    }
  }

  data_flow {
    streams      = local.container_insights_streams
    destinations = ["ciworkspace"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "msci" {
  name                    = "msci-${local.aks_cluster_name}"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.msci.id
}

resource "azurerm_dashboard_grafana" "this" {
  # Managed Grafana names are limited to 23 characters.
  name                  = "grafana-${substr(sha1(azurerm_kubernetes_cluster.this.id), 0, 15)}"
  resource_group_name   = data.azurerm_resource_group.rg.name
  location              = module.locations.name
  grafana_major_version = 13
  sku                   = "Standard"
  tags                  = local.tags

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = var.monitor_workspace_id
  }
}

resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = var.monitor_workspace_id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_admin" {
  for_each = var.admin_object_ids

  scope                = azurerm_dashboard_grafana.this.id
  role_definition_name = "Grafana Admin"
  principal_id         = each.value
}

resource "azurerm_monitor_action_group" "recommended" {
  name                = "RecommendedAlertRules-AG-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  short_name          = "recalert1"
  enabled             = true
  tags                = local.tags

  dynamic "email_receiver" {
    for_each = sort(tolist(var.alert_emails))
    content {
      name                    = "Email_${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_metric_alert" "recommended" {
  for_each = local.metric_alerts

  name                = "${each.value.name} - ${local.aks_cluster_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  scopes              = [azurerm_kubernetes_cluster.this.id]
  severity            = 3
  enabled             = true
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = each.value.metric_name
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.recommended.id
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                           = "aks-control-plane"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset([
      "kube-apiserver",
      "kube-audit-admin",
      "kube-controller-manager",
      "kube-scheduler",
      "cluster-autoscaler",
      "cloud-controller-manager",
      "guard",
    ])

    content {
      category = enabled_log.value
    }
  }
}
