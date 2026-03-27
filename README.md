# AKS Designs

An Azure Kubernetes Service reference architecture deployed end-to-end with `azd up` and [ArgoCD](https://argo-cd.readthedocs.io/) using the [App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/). The infrastructure is defined in Terraform using a **3-tier module structure**:

- **Base modules** (`infra/modules/base_modules/`), single-resource building blocks (VNet, subnet, firewall, AKS cluster, etc.)
- **Pattern modules** (`infra/modules/pattern_*/`), composable patterns that combine base modules (hub, spoke, spoke_dns, spoke_aks, monitoring, routing)
- **Root module** (`infra/main.tf`), orchestrates patterns into a complete hub-and-spoke network with AKS, firewall, private DNS, and optional monitoring

## How It Works

`azd up` provisions infrastructure, installs ArgoCD, and bootstraps a GitOps pipeline:

```PowerShell
$env:PYTHONUTF8 = "1"
azd provision
  └── Terraform creates AKS, ACR, Key Vault, VNets, firewall, etc.

postprovision.ps1
  ├── Gets AKS credentials
  ├── Initializes TLS certificates in Key Vault
  └── Builds and pushes container images to ACR

azd deploy
  └── Installs ArgoCD (argo/argo-cd v9.4.15) into the argocd namespace

postdeploy.ps1
  ├── Creates a root ArgoCD Application pointing to src/apps in this Git repo
  ├── ArgoCD syncs the App of Apps chart, which creates 4 child Applications
  ├── Each child Application points to a chart in src/charts/ (GitOps from this repo)
  ├── Sync waves enforce ordering: infra-base (1) → gateway + identity (2) → tenant (3)
  ├── A PostSync hook on infra-base verifies Key Vault secrets are synced before wave 2 starts
  ├── Waits for all applications to be Healthy and Synced
  ├── Gets the Gateway external IP and updates DuckDNS records
  └── Initializes the Keycloak realm, clients, and test user
```

After the initial bootstrap, ArgoCD continuously watches this Git repository. Pushing chart changes to `main` triggers automatic sync, no manual deployment needed.

## Architecture

Deployment is organized into four Helm charts, managed by ArgoCD via sync waves:

| Wave | Chart | Namespace | Contents |
|---|---|---|---|
| 1 | `infra-base` | `infra` | SecretProviderClass, secrets-sync, PostSync secrets verification hook |
| 2 | `gateway` | `infra` | ApplicationLoadBalancer, Gateway, FrontendTLSPolicy, Keycloak HTTPRoute |
| 2 | `identity` | `identity` | Keycloak StatefulSet, Postgres, ReferenceGrant |
| 3 | `tenant` | `<tenant-name>` | React App, API Service, HealthCheckPolicies, HTTPRoute, ReferenceGrant |

**Why this order matters:** `infra-base` must complete before `gateway` because it creates the `SecretProviderClass` and `secrets-sync` pod that pull TLS certificates from Azure Key Vault into Kubernetes Secrets (`gateway-tls-secret` and `ca.bundle`). A PostSync hook verifies these secrets exist before ArgoCD proceeds to wave 2. The `gateway` chart references those Secrets for HTTPS termination and mTLS.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [PowerShell 7.5+](https://learn.microsoft.com/PowerShell/scripting/install/installing-PowerShell)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

## Setup

Enable the `azd` Helm alpha feature (required once per machine):

```PowerShell
azd config set alpha.aks.helm on
```

## Quick Start

```PowerShell
# Create the environment
azd env new nonprod

# --- Infrastructure settings ---
azd env set AKS_NODE_POOL_VM_SIZE "Standard_D2as_v7"
azd env set AZURE_ENV_NAME "nonprod"
azd env set AZURE_WORKLOAD_ENV_NAME "dev"
azd env set AZURE_LOCATION "westus3"
azd env set AZURE_SUBSCRIPTION_ID "<your subscription id>"
azd env set AZURE_TENANT_ID "<your tenant id>"
azd env set ADMIN_GROUP_OBJECT_IDS "<comma-separated Entra group object IDs>"
azd env set ALERT_EMAIL "<your email>"

# --- Application settings ---
azd env set CUSTOMER_TENANT_NAMES "<space-separated tenant names, e.g. zach-a zach-b>"
azd env set APP_HOSTNAME "<primary fqdn for certs, e.g. myapp.duckdns.org>"
azd env set IDENTITY_PROVIDER_HOSTNAME "<fqdn for keycloak, e.g. mykeycloak.duckdns.org>"
azd env set DUCKDNS_TOKEN "<your duckdns.org token>"
```

```PowerShell
# Provision infrastructure and deploy the application
azd up
```

> **Important:** All chart changes must be pushed to `main` on GitHub before running `azd up`, because ArgoCD pulls from the remote Git repository, not your local working directory.

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `AZURE_ENV_NAME` | Yes | Environment name (e.g., `nonprod`) |
| `AZURE_WORKLOAD_ENV_NAME` | Yes | Workload environment (e.g., `dev`) |
| `AZURE_LOCATION` | Yes | Azure region (e.g., `westus3`) |
| `AZURE_SUBSCRIPTION_ID` | Yes | Azure subscription ID |
| `AZURE_TENANT_ID` | Yes | Azure tenant ID |
| `AKS_NODE_POOL_VM_SIZE` | Yes | VM size for AKS node pool (e.g., `Standard_D2as_v7`) |
| `ADMIN_GROUP_OBJECT_IDS` | Yes | Comma-separated Entra ID group object IDs for AKS admin access |
| `ALERT_EMAIL` | Yes | Email address for AKS alert notifications |
| `CUSTOMER_TENANT_NAMES` | Yes | Space-separated tenant identifiers — each is used as a Kubernetes namespace, ArgoCD Application name, and Keycloak realm name |
| `APP_HOSTNAME` | Yes | Primary FQDN used for TLS certificate SAN generation |
| `IDENTITY_PROVIDER_HOSTNAME` | Yes | FQDN for Keycloak |
| `DUCKDNS_TOKEN` | Yes | DuckDNS API token |

## Accessing ArgoCD

```PowerShell
# Get the admin password
$argoPass = kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' |
    ForEach-Object { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
Write-Host "Username: admin"
Write-Host "Password: $argoPass"

# Port-forward the ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

Open https://localhost:8443 and login with `admin` and the password above.

## Tear Down

```PowerShell
azd down --force --purge
```

## Adding Additional Tenants

To onboard additional tenants, add a new Application to the App of Apps chart in `src/apps/templates/` and push to Git. ArgoCD will automatically sync the new tenant.

Alternatively, deploy manually:

### 1. Deploy the tenant chart

```PowerShell
helm upgrade --install tenant-zach-b src/charts/tenant `
    --namespace zach-b --create-namespace `
    --set tenantName=zach-b `
    --set acrName=$env:ACR_NAME `
    --set appHostname=zach-b.duckdns.org `
    --set identityProviderHostname=$env:IDENTITY_PROVIDER_HOSTNAME `
    --wait --timeout 5m
```

This creates:
- A `ReferenceGrant` allowing the gateway to route to services in the namespace
- An `HTTPRoute` in the `infra` namespace routing `zach-b.duckdns.org` traffic
- The API service and React app Deployments, Services, and HealthCheckPolicies

### 2. Update TLS certificates

If the new tenant uses a hostname not covered by the existing server certificate SANs, re-run `Initialize-Certs.ps1` with all hostnames. If all tenants share a wildcard domain already covered by the cert, no changes are needed.

### 3. Update DuckDNS

```PowerShell
$gatewayIp = & src/weather-app/Get-GatewayIpAddress.ps1

& src/weather-app/Update-DuckDns.ps1 `
    -Token $env:DUCKDNS_TOKEN `
    -Hostnames "zach-b.duckdns.org" `
    -IpAddress $gatewayIp
```

### 4. Create the Keycloak realm

```PowerShell
& src/weather-app/Initialize-KeycloakRealm.ps1 `
    -RealmName zach-b `
    -KeycloakBaseUrl "https://$env:IDENTITY_PROVIDER_HOSTNAME"
```

### Managing tenants

```PowerShell
# List all ArgoCD-managed tenant applications
kubectl get applications -n argocd | Select-String "tenant-"

# Remove a tenant (if manually deployed)
helm uninstall tenant-zach-b --namespace zach-b
kubectl delete namespace zach-b
```
