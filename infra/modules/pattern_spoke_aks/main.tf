locals {
  module_tags = tomap(
    {
      terraform-azurerm-composable-level2 = "pattern_spoke_aks"
    }
  )

  tags = merge(
    local.module_tags,
    var.tags
  )
  # AKS VNet subnet allocation using cidrsubnets for variable-sized subnets.
  # For a /22 VNet, newbits values produce:
  # Layout (for 10.100.12.0/22):
  #   [0] aks-cluster /24           10.100.12.0/24
  #   [1] aks-alb /24               10.100.13.0/24
  #   [2] agw-24 /24                10.100.14.0/24
  #   [3] aks-api-server /28        10.100.15.0/28
  #   [4] aks-private-endpoints /28 10.100.15.16/28

  aks_subnets = cidrsubnets(var.address_space[0], 2, 2, 2, 6, 6)

  subnets = [
    {
      workload         = "aks-cluster", // needs to be a size /24
      instance         = "001"
      delegation       = {}
      subnet           = local.aks_subnets[0]
      service_endpoint = []
    },
    {

      # Application Gateway for Containers Subnet
      workload = "aks-alb", // Needs to be a size /24
      instance = "001"
      delegation = {
        "aks-alb-delegation" = {
          name    = "Microsoft.ServiceNetworking/trafficControllers",
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }
      subnet           = local.aks_subnets[1]
      service_endpoint = []
    },
    {
      # Roll your own Application Gateway subnet. 
      workload         = "agw-subnet", // Needs to be a size /24
      instance         = "001"
      delegation       = {}
      subnet           = local.aks_subnets[2]
      service_endpoint = []
    },
    {
      workload = "aks-api-server", // Needs to be a size /28
      instance = "001"
      delegation = {
        "aks-api-server-delegation" = {
          name    = "Microsoft.ContainerService/managedClusters",
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }
      service_endpoint = []
      subnet           = local.aks_subnets[3]
    },
    {
      workload         = "aks-private-endpoints", // Hosts private endpoints for this spoke
      instance         = "001"
      delegation       = {}
      service_endpoint = []
      subnet           = local.aks_subnets[4]
    }
  ]

  agw_hostnames = distinct([
    for key in sort(keys(var.application_gateway_applications)) : var.application_gateway_applications[key].hostname
  ])

  agw_certificate_common_name = try(coalesce(var.application_gateway_certificate_common_name, local.agw_hostnames[0]), null)

  agw_certificate_name = join("-", compact([var.workload, var.random_string, "agw-frontend-tls"]))

  # The shared spoke rules deny inbound Internet traffic, which the Application Gateway subnet
  # cannot tolerate: it needs the control plane ports and the public frontend ports.
  agw_network_security_rules = [
    {
      name                       = "A-IN-GatewayManager-Any-TCP-65200-65535"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    },
    {
      name                       = "A-IN-AzureLoadBalancer-Any"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    },
    {
      name                       = "A-IN-Internet-Any-TCP-80"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    },
    {
      name                       = "A-IN-Internet-Any-TCP-443"
      priority                   = 210
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  ]
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

module "subnets" {
  for_each = { for i, subnet in local.subnets : subnet.workload => merge(subnet, { index = i }) }
  source   = "../base_modules/subnet"

  address_prefixes                     = [each.value.subnet]
  delegation                           = each.value.delegation
  environment                          = var.environment
  instance                             = format("%03d", each.value.instance)
  location                             = var.location
  random_string                        = var.random_string
  resource_group_name                  = module.resource_group.name
  service_endpoint                     = each.value.service_endpoint
  snet_default_outbound_access_enabled = false
  virtual_network_name                 = module.virtual_network.name
  workload                             = each.value.workload
}

module "virtual_network_peerings" {
  source                                = "../base_modules/virtual_network_peerings"
  virtual_network_1_resource_group_name = var.hub_resource_group_name
  virtual_network_1_id                  = var.hub_virtual_network_id
  virtual_network_1_hub                 = true
  virtual_network_2_resource_group_name = module.resource_group.name
  virtual_network_2_id                  = module.virtual_network.id
  gateway_exists                        = var.gateway_exists
}

module "routing" {
  source = "../pattern_routing"
  additional_subnet_ids = {
    "aks-api-server" = module.subnets["aks-api-server"].id
  }
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  next_hop            = var.subnets_next_hop
  next_hop_type       = "VirtualAppliance"
  random_string       = var.random_string
  resource_group_name = module.resource_group.name
  subnet_id           = module.subnets["aks-cluster"].id
  tags                = local.tags
  workload            = var.workload
}

module "network_security_group" {
  source              = "../base_modules/network_security_group"
  count               = var.network_security_group ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  resource_group_name = module.resource_group.name
  workload            = var.workload
}

module "network_security_rules" {
  source                      = "../base_modules/network_security_rule"
  count                       = var.network_security_group ? length(var.network_security_rules) : 0
  access                      = var.network_security_rules[count.index].access
  destination_address_prefix  = var.network_security_rules[count.index].destination_address_prefix
  destination_port_range      = var.network_security_rules[count.index].destination_port_range
  direction                   = var.network_security_rules[count.index].direction
  name                        = var.network_security_rules[count.index].name
  network_security_group_name = module.network_security_group[0].name
  priority                    = var.network_security_rules[count.index].priority
  protocol                    = var.network_security_rules[count.index].protocol
  resource_group_name         = module.resource_group.name
  source_address_prefix       = var.network_security_rules[count.index].source_address_prefix
  source_port_range           = var.network_security_rules[count.index].source_port_range
}

module "subnet_network_security_group_association" {
  source                    = "../base_modules/subnet_network_security_group_association"
  for_each                  = var.network_security_group ? { for name, subnet in module.subnets : name => subnet if !(var.application_gateway && name == "agw-subnet") } : {}
  network_security_group_id = module.network_security_group[0].id
  subnet_id                 = each.value.id
}

# TODO: This should be in a shared RG, not the AKS RG. 
module "acr" {
  source                     = "../base_modules/container_registry"
  random_string              = var.random_string
  environment                = var.environment
  instance                   = var.instance
  location                   = var.location
  log_analytics_workspace_id = var.log_analytics_workspace_id
  resource_group_name        = module.resource_group.name
  workload                   = var.workload
  tags                       = local.tags
}

module "aks" {
  source = "../base_modules/kubernetes_services"
  addons_profile = {
    advanced_network_policies = {
      enabled = true
      observability = {
        enabled = true
      }
      performance = {
        accelerationMode = "BpfVeth"
      }
      security = {
        enabled                 = true
        advancedNetworkPolicies = "FQDN"
        cilium_mtls = {
          enabled = true
        }
      }
    }
    application_gateway_for_containers = {
      enabled = false
    }
    application_routing_gateway_api = {
      enabled = true
    }
    node_auto_provisioning = {
      enabled = true
    }
  }

  user_node_pools = {
    "user_node_pool_1" = {
      name           = "d4adsv7zone1"
      node_count     = 1
      os             = "AzureLinux"
      vm_size        = "Standard_D4ads_v7"
      vnet_subnet_id = module.subnets["aks-cluster"].id
      upgrade_settings = {
        drain_timeout_in_minutes      = 0
        max_surge                     = "10%"
        node_soak_duration_in_minutes = 0
      }
    }
  }

  system_node_pool = {
    name                         = "systempool"
    vm_size                      = var.vm_size
    zones                        = ["1", "2", "3"]
    os                           = "AzureLinux"
    min_count                    = 1
    max_count                    = 8
    max_pods                     = 110
    vnet_subnet_id               = module.subnets["aks-cluster"].id
    only_critical_addons_enabled = true
  }

  admin_object_ids             = var.admin_object_ids
  aks_alb_snet                 = module.subnets["aks-alb"].id
  private_api_server_subnet_id = module.subnets["aks-api-server"].id
  aks_vnet_id                  = module.virtual_network.id
  alert_email                  = var.alert_email
  authorized_ip_ranges         = var.authorized_ip_ranges
  container_registry_id        = module.acr.id
  environment                  = var.environment
  instance                     = var.instance
  location                     = var.location
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  monitor_workspace_id         = var.monitor_workspace_id
  outbound_type                = "userDefinedRouting"
  private_api_server           = var.enable_private_api_server
  private_dns_zone_id          = var.private_dns_zone_id
  random_string                = var.random_string
  resource_group_name          = module.resource_group.name
  tenant_id                    = var.tenant_id
  workload                     = var.workload
  workload_identity            = true

  tags = local.tags

  oidc_issuer_profile = {
    enabled = true
  }

  depends_on = [
    module.virtual_network_peerings,
    module.routing
  ]
}

module "private_key_vault" {
  source = "../composite_modules/private_key_vault"

  environment                            = var.environment
  instance                               = var.instance
  key_vault_private_dns_zone_resource_id = var.key_vault_private_dns_zone_resource_id
  location                               = var.location
  private_endpoint_subnet_resource_id    = module.subnets["aks-private-endpoints"].id
  random_string                          = var.random_string
  resource_group_name                    = module.resource_group.name
  tags                                   = local.tags
  tenant_id                              = var.tenant_id
  workload                               = var.workload
}

resource "azurerm_role_assignment" "admin_keyvault_administrator" {
  for_each             = toset(var.admin_object_ids)
  principal_id         = each.value
  scope                = module.private_key_vault.id
  role_definition_name = "Key Vault Administrator"
}

# The Application Gateway for Containers (ALB) addon is currently disabled in the
# kubernetes_services module, so its identity does not exist to grant Key Vault access to.
# See base_modules/kubernetes_services/outputs.tf: alb_identity_principal_id.
# resource "azurerm_role_assignment" "alb_keyvault_secrets_user" {
#   count                = var.application_gateway_for_containers ? 1 : 0
#   principal_id         = module.aks.alb_identity_principal_id
#   scope                = module.private_key_vault.id
#   role_definition_name = "Key Vault Secrets User"
# }

resource "azurerm_role_assignment" "kubelet_keyvault_secrets_user" {
  principal_id         = module.aks.kubelet_identity_principal_id
  scope                = module.private_key_vault.id
  role_definition_name = "Key Vault Secrets User"
}

module "public_ip_agw" {
  source              = "../base_modules/public_ip"
  count               = var.application_gateway ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  resource_group_name = module.resource_group.name
  tags                = local.tags
  workload            = "agw"
}

resource "azurecaf_name" "agw_identity" {
  count         = var.application_gateway ? 1 : 0
  name          = "agw-${var.workload}"
  resource_type = "azurerm_user_assigned_identity"
  prefixes      = [var.environment]
  suffixes      = var.random_string != "" ? [var.random_string, var.instance] : [var.instance]
  clean_input   = true
}

resource "azurerm_user_assigned_identity" "agw" {
  count               = var.application_gateway ? 1 : 0
  name                = azurecaf_name.agw_identity[0].result
  location            = module.locations.name
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "agw_keyvault_secrets_user" {
  count                = var.application_gateway ? 1 : 0
  principal_id         = azurerm_user_assigned_identity.agw[0].principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = module.private_key_vault.id
}

resource "azurerm_key_vault_certificate" "agw_frontend_cert" {
  count        = var.application_gateway ? 1 : 0
  name         = local.agw_certificate_name
  key_vault_id = module.private_key_vault.id
  tags         = local.tags

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=${local.agw_certificate_common_name}"
      validity_in_months = 12
      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = local.agw_hostnames
      }
    }
  }

  depends_on = [azurerm_role_assignment.admin_keyvault_administrator]

  lifecycle {
    precondition {
      condition     = local.agw_certificate_common_name != null
      error_message = "Set application_gateway_certificate_common_name, or provide at least one application in application_gateway_applications."
    }
  }
}

module "network_security_group_agw" {
  source              = "../base_modules/network_security_group"
  count               = var.application_gateway ? 1 : 0
  environment         = var.environment
  instance            = var.instance
  location            = var.location
  random_string       = var.random_string
  resource_group_name = module.resource_group.name
  tags                = local.tags
  workload            = "agw"
}

module "network_security_rules_agw" {
  source                      = "../base_modules/network_security_rule"
  for_each                    = var.application_gateway ? { for rule in local.agw_network_security_rules : rule.name => rule } : {}
  access                      = each.value.access
  destination_address_prefix  = each.value.destination_address_prefix
  destination_port_range      = each.value.destination_port_range
  direction                   = each.value.direction
  name                        = each.value.name
  network_security_group_name = module.network_security_group_agw[0].name
  priority                    = each.value.priority
  protocol                    = each.value.protocol
  resource_group_name         = module.resource_group.name
  source_address_prefix       = each.value.source_address_prefix
  source_port_range           = each.value.source_port_range
}

module "subnet_network_security_group_association_agw" {
  source                    = "../base_modules/subnet_network_security_group_association"
  count                     = var.application_gateway ? 1 : 0
  network_security_group_id = module.network_security_group_agw[0].id
  subnet_id                 = module.subnets["agw-subnet"].id
}

module "application_gateway" {
  source = "../base_modules/application_gateway"
  count  = var.application_gateway ? 1 : 0

  appgw_applications = var.application_gateway_applications
  # Static internal load balancer IP of the in-cluster Gateway API gateway.
  # See k8s/infrastructure/configs/gateway/gateway.yaml.
  backend_ip_addresses                = var.application_gateway_backend_ip_addresses
  environment                         = var.environment
  frontend_ip_name                    = "agw"
  identity_id                         = azurerm_user_assigned_identity.agw[0].id
  instance                            = var.instance
  location                            = var.location
  public_ip_address_id                = module.public_ip_agw[0].id
  random_string                       = var.random_string
  resource_group_name                 = module.resource_group.name
  ssl_certificate_key_vault_secret_id = azurerm_key_vault_certificate.agw_frontend_cert[0].versionless_secret_id
  subnet_id                           = module.subnets["agw-subnet"].id
  tags                                = local.tags
  trusted_root_certificate_pem        = var.application_gateway_trusted_root_certificate_pem
  workload                            = var.workload

  depends_on = [azurerm_role_assignment.agw_keyvault_secrets_user]
}
