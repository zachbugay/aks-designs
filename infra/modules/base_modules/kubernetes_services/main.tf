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
resource "azurerm_user_assigned_identity" "identity" {
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
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  scope                = azurerm_user_assigned_identity.kubelet_identity.id
  role_definition_name = "Managed Identity Operator"
}

resource "azurerm_role_assignment" "network_contributor" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  scope                = var.aks_vnet_id
  role_definition_name = "Network Contributor"
}

# resource "azurerm_role_assignment" "private_dns_zone_contributor" {
#   principal_id         = azurerm_user_assigned_identity.identity.principal_id
#   scope                = azurerm_private_dns_zone.zone.id
#   role_definition_name = "Private DNS Zone Contributor"
# }

module "aks" {
  source    = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version   = "0.5.3"
  location  = data.azurerm_resource_group.rg.location
  name      = coalesce(var.custom_name, azurecaf_name.this.result)
  parent_id = data.azurerm_resource_group.rg.id

  aad_profile = {
    admin_group_object_ids = var.admin_group_object_ids
    enable_azure_rbac      = var.enable_azure_rbac # true
    managed                = var.entra_managed     # true
    tenant_id              = var.tenant_id
  }

  addon_profile_oms_agent = {
    enabled = true
    config = {
      log_analytics_workspace_resource_id = var.log_analytics_workspace_id
      use_aad_auth                        = true
    }
  }

  addon_profile_key_vault_secrets_provider = {
    enabled = true
    config = {
      enable_secret_rotation = true
      rotation_poll_interval = "2m"
    }
  }

  # agent_pools = {
  #   usernodepool1 = {
  #     name                = "unp1" # TODO
  #     vm_size             = var.vm_size
  #     availability_zones  = ["1"] # TODO
  #     enable_auto_scaling = true
  #     max_count           = 3
  #     max_pods            = 110
  #     min_count           = 2
  #     os_disk_size_gb     = 60
  #     vnet_subnet_id      = var.aks_cluster_subnet
  #     upgrade_settings = {
  #       max_surge = "100%"
  #     }
  #     os_sku = "AzureLinux"
  #   }
  # }

  api_server_access_profile = {
    authorized_ip_ranges   = var.authorized_ip_ranges
    enable_private_cluster = false
  }

  # Auto upgrade profile defaults
  #   var.autoupgrade_profile.default = {
  #   node_os_upgrade_channel = "NodeImage"
  #   upgrade_channel         = "rapid"
  # }
  # https://learn.microsoft.com/en-us/azure/aks/auto-upgrade-node-os-image?tabs=azure-cli
  auto_upgrade_profile = var.auto_upgrade_profile

  default_agent_pool = {
    name                = "systempool"
    vm_size             = var.vm_size
    availability_zones  = ["1"] # TODO
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 5
    max_pods            = 110
    vnet_subnet_id      = var.aks_cluster_subnet
    mode                = "System"
    # node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
    upgrade_settings = {
      max_surge = "50%"
    }
    os_sku = "AzureLinux"
  }

  oidc_issuer_profile    = var.oidc_issuer_profile
  disable_local_accounts = var.disable_local_accounts

  identity_profile = {
    kubeletidentity = {
      resource_id = azurerm_user_assigned_identity.kubelet_identity.id
    }
  }

  maintenanceconfiguration = {
    aksManagedAutoUpgradeSchedule = {
      name = "aksManagedAutoUpgradeSchedule"
      maintenance_window = {
        duration_hours = 4
        start_time     = "00:00"
        utc_offset     = "-05:00" # EST
        start_date     = "2026-02-26"
        schedule = {
          weekly = {
            day_of_week    = "Wednesday"
            interval_weeks = 1
          }
        }
      }
    }
  }

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.identity.id]
  }

  service_mesh_profile = {
    mode = "Istio"
    istio = {
      revisions = var.istio_revisions
    }
  }

  network_profile = {
    outbound_type       = var.outbound_type
    service_cidr        = "10.233.0.0/16"
    dns_service_ip      = "10.233.0.10"
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_dataplane   = "cilium"
    load_balancer_sku   = "standard"
    advanced_networking = {
      enabled = true
      observability = {
        enabled = true
      }
      security = {
        enabled                   = true
        advanced_network_policies = "L7"
      }
    }
  }

  azure_monitor_profile = {
    metrics = {
      enabled = true
      kube_state_metrics = {
        metric_annotations_allow_list = null
        metric_labels_allowlist       = "nodes=[kubernetes.azure.com/agentpool,node.kubernetes.io/instance-type,topology.kubernetes.io/zone,kubernetes.azure.com/os-sku],pods=[app,app.kubernetes.io/name,app.kubernetes.io/component,app.kubernetes.io/version,app.kubernetes.io/managed-by],deployments=[app,app.kubernetes.io/name,app.kubernetes.io/component],namespaces=[kubernetes.io/metadata.name],statefulsets=[app,app.kubernetes.io/name,app.kubernetes.io/component],daemonsets=[app,app.kubernetes.io/name,app.kubernetes.io/component],jobs=[app,app.kubernetes.io/name,app.kubernetes.io/component]"
      }
    }
  }

  onboard_alerts          = true
  alert_email             = var.alert_email
  onboard_monitoring      = true
  prometheus_workspace_id = var.monitor_workspace_id

  security_profile = {
    image_cleaner = {
      enabled        = true
      interval_hours = 168
    }

    defender = {
      log_analytics_workspace_resource_id = var.log_analytics_workspace_id
      security_monitoring = {
        enabled = true
      }
    }

    workload_identity = {
      enabled = var.workload_identity
    }
  }

  dns_prefix         = coalesce(var.dns_prefix, azurecaf_name.this.result)
  kubernetes_version = var.kubernetes_version

  storage_profile = {
    file_csi_driver = {
      enabled = true
    }
  }

  sku = {
    name = "Base"
    tier = "Free" # Standard or Premium
  }

  depends_on = [
    azurerm_role_assignment.managed_identity_operator,
    azurerm_role_assignment.network_contributor
  ]
}

module "role_assignments" {
  source  = "Azure/avm-res-authorization-roleassignment/azurerm"
  version = "0.3.0"

  user_assigned_managed_identities_by_client_id = {
    kubelet_identity = module.aks.kubelet_identity.clientId
  }

  role_definitions = {
    acr_pull_role = {
      name = "AcrPull"
    }

    storage_file_data_smb_mi_admin = {
      name = "Storage File Data SMB MI Admin"
    }
  }

  role_assignments_for_scopes = {
    # AKS pull from our ACR.
    aks_acr = {
      scope = var.container_registry_id
      role_assignments = {
        role_assignment_1 = {
          role_definition                  = "acr_pull_role"
          user_assigned_managed_identities = ["kubelet_identity"]
        }
      }
    }

    # On the user defined resource_group.
    aks_user_node_assignments = {
      scope = data.azurerm_resource_group.rg.id
      role_assignments = {
        role_assignment_1 = {
          role_definition                  = "storage_file_data_smb_mi_admin"
          user_assigned_managed_identities = ["kubelet_identity"]
        }
      }
    }
  }

  depends_on = [module.aks]
}

# Federated identity credentials for Kubernetes workload identity
# TODO: For now, this is going to federate into the default namespace. Figure out a better way.
resource "azurerm_federated_identity_credential" "this" {
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks.oidc_issuer_profile_issuer_url
  name      = "fc-${azurerm_user_assigned_identity.kubelet_identity.name}"
  parent_id = azurerm_user_assigned_identity.kubelet_identity.id
  subject   = "system:serviceaccount:default:${azurerm_user_assigned_identity.kubelet_identity.name}"
}

# Enable the Application Gateway for Containers (ALB Controller) managed addon
# and the Gateway API addon on the AKS cluster.
# See: https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon
resource "azapi_update_resource" "alb_controller_addon" {
  count       = var.application_gateway_for_containers ? 1 : 0
  type        = "Microsoft.ContainerService/managedClusters@2025-10-02-preview"
  resource_id = module.aks.resource_id

  body = {
    properties = {
      ingressProfile = {
        applicationLoadBalancer = {
          enabled = true
        }
        gatewayAPI = {
          installation = "Standard"
        }
      }
    }
  }

  depends_on = [module.aks]
}

# Identity for the Application Load Balancer for the Addon.
data "azurerm_user_assigned_identity" "applicationloadbalancer" {
  name                = "applicationloadbalancer-${module.aks.name}"
  resource_group_name = module.aks.node_resource_group_name
  depends_on = [azapi_update_resource.alb_controller_addon]
}

resource "azurerm_role_assignment" "alb_network_contributor" {
  principal_id         = data.azurerm_user_assigned_identity.applicationloadbalancer.principal_id
  scope                = var.aks_lb_snet
  role_definition_name = "Network Contributor"
}
