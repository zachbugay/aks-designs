# AKS Designs

## How It Works

`azd up` provisions infrastructure, installs FluxCD onto the cluster, and bootstraps a GitOps pipeline.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure CLI Extension Monitor Control Services](https://github.com/Azure/azure-cli-extensions/blob/main/src/monitor-control-service/README.md)
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Terraform >= 1.14.5](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [fluxcd](https://fluxcd.io/flux/installation/)

### Optional

- [Helm](https://helm.sh/docs/intro/install/)

## Install Azure CLI Extensions

Install the required Azure CLI extensions:

```bash
az extension add --name monitor-control-service --yes
```

## Environment Variables Reference

| Variable                     | Required | Description                                                    |
| ---------------------------- | -------- | ---------------------------------------------------------------|
| `AZURE_ENV_NAME`             | Yes      | Environment name (e.g., `nonprod`)                             |
| `AZURE_LOCATION`             | Yes      | Azure region (e.g., `westus3`)                                 |
| `AZURE_SUBSCRIPTION_ID`      | Yes      | Azure subscription ID                                          |
| `AZURE_TENANT_ID`            | Yes      | Azure tenant ID                                                |
| `GITHUB_REPO_NAME`           | Yes      | Name of your GitHub repo                                       |
| `GITHUB_TOKEN`               | Yes      | Token flux can use for GitOps                                  |
| `GITHUB_USERNAME`            | Yes      | Username, organiztion, or enterprise name                      |
| `LANDING_ZONE_CONFIG`        | Yes      | Relative path to your yaml config file                         |


## Quick Start

```PowerShell
# Set the standard AZD Environment Variables
# https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/manage-environment-variables?tabs=bash#standard-environment-variables

# Create the Azure Developer Environment
azd env new "nonprod"

azd env set AZURE_LOCATION "southcentral"
azd env set AZURE_SUBSCRIPTION_ID "<your subscription id>"
azd env set AZURE_TENANT_ID "<your tenant id>"

# Github Specifics
azd env set GITHUB_REPO_NAME "<your-repo>"
azd env set GITHUB_TOKEN "<your-token>"
azd env set GITHUB_USERNAME "<your-username>"

# Set your local yaml config
azd env set LANDING_ZONE_CONFIG="../nonprod.local.yaml"
```

## TODO: 
- The k8s/infrastructure/configs/gateway/gateway.yaml annotations need updated with the correct subnet, dynamically.
- The agw needs to have its backend pool IP updated to the internal load balancer created.
- Spoke AKS should create the AKS cluster, and that's it. My Application Landing Zone should create and configure my AGW. 

## Azure DevOps Agent UAMI Token Setup

```PowerShell
# Azure DevOps Resource ID
$adoResourceId="499b84ac-1321-427f-aa17-267ca6975798"

# Login as the UAMI.
az login --identity --allow-no-subscriptions 

# Get the token.
token=$(az account get-access-token --resource $adoResourceId --query "accessToken" -o tsv)

```