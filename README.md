# AKS Designs

## How It Works

`azd up` provisions infrastructure, installs FluxCD onto the cluster, and bootstraps a GitOps pipeline.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Terraform >= 1.14.5](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [fluxcd](https://fluxcd.io/flux/installation/)

### Optional

- [Helm](https://helm.sh/docs/intro/install/)

## Environment Variables Reference

| Variable                     | Required | Description                                                                                                                        |
| ---------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `AZURE_ENV_NAME`             | Yes      | Environment name (e.g., `nonprod`)                                                                                                 |
| `AZURE_WORKLOAD_ENV_NAME`    | Yes      | Workload environment (e.g., `dev`)                                                                                                 |
| `AZURE_LOCATION`             | Yes      | Azure region (e.g., `westus3`)                                                                                                     |
| `AZURE_SUBSCRIPTION_ID`      | Yes      | Azure subscription ID                                                                                                              |
| `AZURE_TENANT_ID`            | Yes      | Azure tenant ID                                                                                                                    |
| `ADMIN_OBJECT_IDS`           | Yes      | Comma-separated Entra ID group object IDs for AKS admin access                                                                     |
| `ALERT_EMAIL`                | Yes      | Email address for AKS alert notifications                                                                                          |
| `AZURE_VPN_GATEWAY`          | Yes      | Whether to enable an Azure VPN Gateway or not.                                                                                     |
| `AZURE_FIREWALL`             | Yes      | JSON enabling the Azure Firewall with a specific SKU.                                                                              |
| `AKS_ENVIRONMENT`            | Yes      | AKS Environment (e.g., `dev`)                                                                                                      |

## Quick Start

```PowerShell
# Create the environment
azd env new nonprod

# --- Infrastructure settings ---
azd env set ADMIN_OBJECT_IDS "<comma-separated group object IDs>"
azd env set AKS_NODE_POOL_VM_SIZE "Standard_D4as_v7"
azd env set AKS_ENVIRONMENT "dev"

azd env set ALERT_EMAIL "<your email>"

azd env set AZURE_ENV_NAME "nonprod"
azd env set AZURE_WORKLOAD_ENV_NAME "dev"
azd env set AZURE_LOCATION "westus3"
azd env set AZURE_SUBSCRIPTION_ID "<your subscription id>"
azd env set AZURE_TENANT_ID "<your tenant id>"
azd env set AZURE_VPN_GATEWAY "true"
# Choose between Basic, Standard, or Premium
azd env set AZURE_FIREWALL="{\"enabled\":true,\"sku_tier\":\"Standard\",\"sku_name\":\"AZFW_VNet\",\"default_rules\":true}"

# Github Specifics
azd env set GITHUB_REPO_NAME "<your-repo>"
azd env set GITHUB_TOKEN "<your-token>"
azd env set GITHUB_USERNAME "<your-username>"
```

## Install Azure CLI Extensions

```bash
az extension add --name monitor-control-service --yes
```


## TODO: 
- The k8s/infrastructure/configs/gateway/gateway.yaml annotations need updated with the correct subnet, dynamically.
- The agw needs to have its backend pool IP updated to the internal load balancer created.
- Spoke AKS should create the AKS cluster, and that's it. My Application Landing Zone should create and configure my AGW. 

```PowerShell

# Azure DevOps Resource ID
$adoResourceId="499b84ac-1321-427f-aa17-267ca6975798"

# Login as the UAMI.
az login --identity --allow-no-subscriptions 

# Get the token.
token=$(az account get-access-token --resource $adoResourceId --query "accessToken" -o tsv)

```