locals {
  module_tags = tomap(
    {
      terraform-azurerm-module = "kubernetes_services",
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )

  instance = coalesce(var.instance, "001")

  acns                = var.addons_profile.advanced_network_policies
  app_routing_enabled = var.addons_profile.application_routing_gateway_api.enabled
  agc_enabled         = var.addons_profile.application_gateway_for_containers.enabled
  nap_enabled         = var.addons_profile.node_auto_provisioning.enabled
  maintenance_window  = var.auto_upgrade_profile.maintenance_window

  workload_labels = ["app.kubernetes.io/name", "app.kubernetes.io/component"]

  metrics_labels_allowed = [
    {
      resource = "nodes"
      labels = [
        "kubernetes.azure.com/agentpool",
        "node.kubernetes.io/instance-type",
        "topology.kubernetes.io/zone",
        "kubernetes.azure.com/os-sku",
      ]
    },
    {
      resource = "pods"
      labels = concat(local.workload_labels, [
        "app.kubernetes.io/version",
        "app.kubernetes.io/managed-by",
      ])
    },
    {
      resource = "deployments"
      labels   = local.workload_labels
    },
    {
      resource = "namespaces"
      labels   = ["kubernetes.io/metadata.name"]
    },
    {
      resource = "statefulsets"
      labels   = local.workload_labels
    },
    {
      resource = "daemonsets"
      labels   = local.workload_labels
    },
    {
      resource = "jobs"
      labels   = local.workload_labels
    },
  ]

  metrics_labels_allowed_string = join(",", [
    for entry in local.metrics_labels_allowed :
    "${entry.resource}=[${join(",", entry.labels)}]"
  ])
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

module "locations" {
  source   = "../locations"
  location = var.location
}

resource "azurecaf_name" "this" {
  name          = var.workload
  resource_type = "azurerm_kubernetes_cluster"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurecaf_name" "aks_identity" {
  name          = "aks-${var.workload}"
  resource_type = "azurerm_user_assigned_identity"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

resource "azurecaf_name" "aks_kubelet_identity" {
  name          = "kubelet-${var.workload}"
  resource_type = "azurerm_user_assigned_identity"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, local.instance] : [local.instance]
  clean_input   = true
}

# Identity for the managed cluster
resource "azurerm_user_assigned_identity" "aks_identity" {
  location            = module.locations.name
  name                = azurecaf_name.aks_identity.result
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Identity for the kubelet, used to pull images from ACR for example
resource "azurerm_user_assigned_identity" "kubelet_identity" {
  location            = module.locations.name
  name                = azurecaf_name.aks_kubelet_identity.result
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "managed_identity_operator" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  scope                = azurerm_user_assigned_identity.kubelet_identity.id
  role_definition_name = "Managed Identity Operator"
}

resource "azurerm_role_assignment" "network_contributor" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  scope                = var.aks_vnet_id
  role_definition_name = "Network Contributor"
}

resource "azurerm_role_assignment" "private_dns_zone_contributor" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
}

resource "azurerm_kubernetes_cluster" "this" {
  name = coalesce(var.custom_name, azurecaf_name.this.result)

  automatic_upgrade_channel    = var.auto_upgrade_profile.upgrade_channel == "none" ? null : var.auto_upgrade_profile.upgrade_channel
  dns_prefix                   = coalesce(var.dns_prefix, azurecaf_name.this.result)
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 168
  kubernetes_version           = var.kubernetes_version
  local_account_disabled       = var.disable_local_accounts
  location                     = data.azurerm_resource_group.rg.location
  node_os_upgrade_channel      = var.auto_upgrade_profile.node_os_upgrade_channel
  oidc_issuer_enabled          = var.oidc_issuer_profile.enabled
  private_cluster_enabled      = var.private_api_server
  private_dns_zone_id          = var.private_dns_zone_id
  resource_group_name          = data.azurerm_resource_group.rg.name
  sku_tier                     = var.sku
  workload_identity_enabled    = var.workload_identity

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet_identity.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet_identity.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet_identity.id
  }

  default_node_pool {
    name    = var.system_node_pool.name
    vm_size = var.system_node_pool.vm_size
    zones   = var.system_node_pool.zones
    # Node auto-provisioning requires enableAutoScaling = false on every agent pool.
    # AKS scales the system pool itself when NAP is enabled.
    auto_scaling_enabled         = !local.nap_enabled
    min_count                    = local.nap_enabled ? null : var.system_node_pool.min_count
    max_count                    = local.nap_enabled ? null : var.system_node_pool.max_count
    node_count                   = local.nap_enabled ? 3 : null
    max_pods                     = var.system_node_pool.max_pods
    vnet_subnet_id               = var.system_node_pool.vnet_subnet_id
    os_sku                       = var.system_node_pool.os
    only_critical_addons_enabled = var.system_node_pool.only_critical_addons_enabled

    upgrade_settings {
      max_surge = "33%"
    }
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_object_ids
    azure_rbac_enabled     = var.enable_azure_rbac
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  node_provisioning_profile {
    mode = var.addons_profile.node_auto_provisioning.enabled ? "Auto" : "Manual"
  }

  storage_profile {
    file_driver_enabled = true
  }

  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = local.metrics_labels_allowed_string
  }

  network_profile {
    outbound_type       = var.outbound_type
    service_cidr        = "10.233.0.0/16"
    dns_service_ip      = "10.233.0.10"
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"

    advanced_networking {
      observability_enabled = var.addons_profile.advanced_network_policies.observability.enabled
      security_enabled      = var.addons_profile.advanced_network_policies.security.enabled
    }
  }

  maintenance_window_auto_upgrade {
    frequency    = local.maintenance_window.frequency
    interval     = local.maintenance_window.interval
    duration     = local.maintenance_window.duration
    day_of_week  = local.maintenance_window.day_of_week
    day_of_month = local.maintenance_window.day_of_month
    week_index   = local.maintenance_window.week_index
    start_time   = local.maintenance_window.start_time
    utc_offset   = local.maintenance_window.utc_offset
    start_date   = local.maintenance_window.start_date

    dynamic "not_allowed" {
      for_each = local.maintenance_window.not_allowed
      content {
        start = not_allowed.value.start
        end   = not_allowed.value.end
      }
    }
  }

  # TODO: What if I want this public with the authorized IP ranges?
  dynamic "api_server_access_profile" {
    for_each = var.private_api_server == true ? [1] : []
    content {
      subnet_id                           = var.private_api_server_subnet_id
      virtual_network_integration_enabled = true
    }
  }

  dynamic "service_mesh_profile" {
    for_each = var.service_mesh_profile.istio.enabled == true ? [1] : []
    content {
      mode                             = "Istio"
      revisions                        = toset(var.service_mesh_profile.istio.istio_revision)
      internal_ingress_gateway_enabled = var.service_mesh_profile.istio.internal_ingress_gateway_enabled
      external_ingress_gateway_enabled = var.service_mesh_profile.istio.external_ingress_gateway_enabled
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
      kubernetes_version,
      location,
      microsoft_defender,
      web_app_routing
    ]
  }

  depends_on = [
    azurerm_role_assignment.managed_identity_operator,
    azurerm_role_assignment.network_contributor
  ]
}

# Node pool names are limited to 12 lowercase alphanumeric characters and must start with a
# letter, so the surge pool name used during rotation is a "t" prefix plus 7 random characters.
resource "random_string" "node_pool_rotation" {
  for_each = var.user_node_pools

  length  = 7
  special = false
  upper   = false

  keepers = {
    node_pool_name = each.value.name
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.user_node_pools

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  name                  = each.value.name

  auto_scaling_enabled        = !local.nap_enabled
  node_count                  = each.value.node_count
  os_sku                      = each.value.os
  temporary_name_for_rotation = "t${random_string.node_pool_rotation[each.key].result}"
  vm_size                     = each.value.vm_size
  vnet_subnet_id              = each.value.vnet_subnet_id

  upgrade_settings {
    drain_timeout_in_minutes      = each.value.upgrade_settings.drain_timeout_in_minutes
    max_surge                     = each.value.upgrade_settings.max_surge
    node_soak_duration_in_minutes = each.value.upgrade_settings.node_soak_duration_in_minutes
  }

  tags = local.tags
}

# AKS kubelet identity pulls images from the shared ACR.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubelet_identity.principal_id
  principal_type       = "ServicePrincipal"
}

# AKS kubelet identity administers Azure Files SMB shares in the resource group.
resource "azurerm_role_assignment" "storage_file_data_smb_mi_admin" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Storage File Data SMB MI Admin"
  principal_id         = azurerm_user_assigned_identity.kubelet_identity.principal_id
  principal_type       = "ServicePrincipal"
}

# Federated identity credentials for Kubernetes workload identity
# TODO: For now, this is going to federate into the default namespace. Figure out a better way.
resource "azurerm_federated_identity_credential" "this" {
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  name                      = "fc-${azurerm_user_assigned_identity.kubelet_identity.name}"
  user_assigned_identity_id = azurerm_user_assigned_identity.kubelet_identity.id
  subject                   = "system:serviceaccount:default:${azurerm_user_assigned_identity.kubelet_identity.name}"
}

# https://learn.microsoft.com/en-us/azure/aks/app-routing-gateway-api#comparison-with-istio-service-mesh-add-on
# https://learn.microsoft.com/en-us/azure/aks/container-network-performance-ebpf-host-routing
# https://learn.microsoft.com/en-us/azure/aks/container-network-security-cilium-mutual-tls-how-to
# https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon
resource "azapi_update_resource" "addons_profile" {
  type        = "Microsoft.ContainerService/managedClusters@2026-04-02-preview"
  resource_id = azurerm_kubernetes_cluster.this.id

  body = {
    properties = {
      networkProfile = {
        advancedNetworking = {
          enabled = local.acns.enabled
          performance = {
            accelerationMode = local.acns.enabled ? local.acns.performance.accelerationMode : "None"
          }
          security = {
            advancedNetworkPolicies = local.acns.security.enabled ? local.acns.security.advancedNetworkPolicies : "None"
            transitEncryption = {
              type = local.acns.security.enabled && local.acns.security.cilium_mtls.enabled ? "mTLS" : "None"
            }
          }
        }
      }
      ingressProfile = {
        gatewayAPI = {
          installation = local.app_routing_enabled || local.agc_enabled ? "Standard" : "Disabled"
        }
        webAppRouting = {
          enabled = local.app_routing_enabled
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = local.app_routing_enabled ? "Enabled" : "Disabled"
            }
          }
          nginx = {
            defaultIngressControllerType = "None"
          }
        }
        applicationLoadBalancer = {
          enabled = local.agc_enabled
        }
      }
    }
  }

  ignore_missing_property = true
}

# Identity for the Application Load Balancer for the Application Gateway for Containers Addon.
# data "azurerm_user_assigned_identity" "applicationloadbalancer" {
#   count               = var.addons_profile.application_gateway_for_containers.enabled ? 1 : 0
#   name                = "applicationloadbalancer-${azurerm_kubernetes_cluster.this.name}"
#   resource_group_name = azurerm_kubernetes_cluster.this.node_resource_group
#   depends_on          = [azapi_update_resource.alb_controller_addon]
# }
#
# resource "azurerm_role_assignment" "alb_network_contributor" {
#   count                = var.addons_profile.application_gateway_for_containers.enabled ? 1 : 0
#   principal_id         = data.azurerm_user_assigned_identity.applicationloadbalancer[count.index].principal_id
#   scope                = var.aks_alb_snet
#   role_definition_name = "Network Contributor"
# }
