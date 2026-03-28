# AKS Designs

An Azure Kubernetes Service reference architecture deployed end-to-end with `azd up` and [ArgoCD](https://argo-cd.readthedocs.io/) using the [App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/). The infrastructure is defined in Terraform using a **3-tier module structure**:

- **Base modules** (`infra/modules/base_modules/`), single-resource building blocks (VNet, subnet, firewall, AKS cluster, etc.)
- **Pattern modules** (`infra/modules/pattern_*/`), composable patterns that combine base modules (hub, spoke, spoke_dns, spoke_aks, monitoring, routing)
- **Root module** (`infra/main.tf`), orchestrates patterns into a complete hub-and-spoke network with AKS, firewall, private DNS, and optional monitoring

## How It Works

`azd up` provisions infrastructure, installs ArgoCD, and bootstraps a GitOps pipeline:

```txt
azd provision
  └── Terraform creates AKS, ACR, Key Vault, VNets, firewall, etc.

postprovision.ps1
  ├── Gets AKS credentials
  ├── Initializes TLS certificates and uploads them to Key Vault
  ├── Stores the DuckDNS token in Key Vault
  ├── Builds and pushes container images to ACR (skips if unchanged)
  └── Updates tenant values.yaml files with the current ACR name

azd deploy
  └── Installs ArgoCD (argo/argo-cd v9.4.15) into the argocd namespace

postdeploy.ps1
  └── Creates a root ArgoCD Application pointing to src/apps in this Git repo
ArgoCD takes over:
  ├── Syncs the App of Apps chart, which creates 3 child Applications
  │   and 1 ApplicationSet (tenants)
  ├── Sync waves enforce ordering: infra-base (1) → gateway + identity (2) → tenants (3)
  ├── A PostSync hook on infra-base verifies Key Vault secrets are synced
  │   before wave 2 starts
  ├── A PostSync hook on gateway updates DuckDNS records with the
  │   Gateway external IP
  └── A PostSync hook on each tenant initializes its Keycloak realm and clients
```

After the initial bootstrap, ArgoCD continuously watches this Git repository. Pushing chart changes to `main` triggers automatic sync, no manual deployment needed.

### Tenant discovery

Tenants are managed as files, not ArgoCD Application manifests. An [ApplicationSet](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/) with a **Git file generator** scans `src/tenants/*/values.yaml` at each sync. To add or remove a tenant, create or delete a values file with `New-Tenant.ps1`, commit, and push, ArgoCD handles the rest.

## Architecture

Deployment is organized into four Helm charts, managed by ArgoCD via sync waves:

| Wave | Chart | Namespace | Contents |
| --- | --- | --- | --- |
| 1 | `infra-base` | `infra` | SecretProviderClass, secrets-sync Deployment, PostSync secrets verification hook |
| 2 | `gateway` | `infra` | ApplicationLoadBalancer, Gateway, FrontendTLSPolicy, Keycloak HTTPRoute, PostSync DuckDNS update hook |
| 2 | `identity` | `identity` | Keycloak StatefulSet, Postgres Deployment, ReferenceGrant |
| 3 | `tenant` (ApplicationSet) | `<tenant-name>` | Namespace (with Istio sidecar injection), NetworkPolicy (deny-all + DNS), CiliumNetworkPolicy (L3/L4), Istio AuthorizationPolicy (L7), Istio ServiceEntry (Keycloak ports 8080 + 80), React App, API Service, HealthCheckPolicies, HTTPRoute, ReferenceGrant, PostSync Keycloak realm init hook |

**Why this order matters:** `infra-base` must complete before `gateway` because it creates the `SecretProviderClass` and `secrets-sync` pod that pull TLS certificates from Azure Key Vault into Kubernetes Secrets (`gateway-tls-secret` and `ca.bundle`). A PostSync hook verifies these secrets exist before ArgoCD proceeds to wave 2. The `gateway` chart references those Secrets for HTTPS termination and mTLS.

**Zero-trust tenant networking:** Each tenant namespace enforces defense in depth. Kubernetes NetworkPolicy establishes a deny-all baseline (ingress and egress) with only DNS allowed. CiliumNetworkPolicy selectively opens L3/L4 ports for each workload (API ingress, Keycloak egress for JWT validation, Istio control plane). Istio AuthorizationPolicy restricts L7 HTTP methods and paths. Cross-tenant traffic is denied at all layers.

**Keycloak port 80 mapping:** The Keycloak Service exposes both port 8080 (primary) and port 80, both targeting the same container port. This is required because Istio's Envoy sidecar strips non-standard ports from the `Host` header when proxying requests. Keycloak then generates OIDC metadata URLs using the default HTTP port (e.g., `http://keycloak.identity.svc.cluster.local/realms/<tenant>/.well-known/openid-configuration`). When the API pod's JWT middleware follows those URLs to fetch JWKS signing keys, the request targets port 80. Without this mapping, JWKS key retrieval fails and all authenticated API calls return 401. The Istio ServiceEntry in the tenant chart and the CiliumNetworkPolicy egress rule both include port 80 for the same reason.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Terraform >= 1.14.5](https://developer.hashicorp.com/terraform/install)
- [PowerShell 7.5+](https://learn.microsoft.com/PowerShell/scripting/install/installing-PowerShell)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [OpenSSL](https://www.openssl.org/) (for TLS certificate generation)

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
azd env set IDENTITY_PROVIDER_HOSTNAME "<fqdn for keycloak, e.g. mykeycloak.duckdns.org>"
azd env set DUCKDNS_TOKEN "<your duckdns.org token>"
```

Create tenant definitions (one values file per tenant under `src/tenants/`):

```PowerShell
./src/weather-app/New-Tenant.ps1 `
    -TenantNames "zach-a", "zach-b" `
    -AcrName "<your ACR name or placeholder>" `
    -IdentityProviderHostname "<keycloak fqdn>"
```

Commit and push the tenant files, then provision and deploy:

```PowerShell
git add src/tenants/ && git commit -m "Add tenants" && git push
azd up
```

> **Important:** All chart and tenant changes must be pushed to `main` on GitHub before running `azd up`, because ArgoCD pulls from the remote Git repository, not your local working directory.

## Environment Variables Reference

| Variable | Required | Description |
| --- | --- | --- |
| `AZURE_ENV_NAME` | Yes | Environment name (e.g., `nonprod`) |
| `AZURE_WORKLOAD_ENV_NAME` | Yes | Workload environment (e.g., `dev`) |
| `AZURE_LOCATION` | Yes | Azure region (e.g., `westus3`) |
| `AZURE_SUBSCRIPTION_ID` | Yes | Azure subscription ID |
| `AZURE_TENANT_ID` | Yes | Azure tenant ID |
| `AKS_NODE_POOL_VM_SIZE` | Yes | VM size for AKS node pool (e.g., `Standard_D4as_v7`) |
| `ADMIN_GROUP_OBJECT_IDS` | Yes | Comma-separated Entra ID group object IDs for AKS admin access |
| `ALERT_EMAIL` | Yes | Email address for AKS alert notifications |
| `IDENTITY_PROVIDER_HOSTNAME` | Yes | FQDN for Keycloak (e.g., `mykeycloak.duckdns.org`) |
| `DUCKDNS_TOKEN` | Yes | DuckDNS API token for automatic DNS record updates |

> Tenant-specific settings (`tenantName`, `acrName`, `appHostname`, `identityProviderHostname`) are defined in each tenant's `src/tenants/<name>/values.yaml`, not as `azd` environment variables. The `postprovision` hook automatically updates `acrName` in tenant values files after provisioning.

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

Run `New-Tenant.ps1` to create the tenant values file, then commit and push. The ArgoCD ApplicationSet detects the new file and deploys the tenant automatically, including the Keycloak realm init and DuckDNS update (via PostSync hooks).

> **Note:** Terraform outputs like `ACR_NAME` and `IDENTITY_PROVIDER_HOSTNAME` are stored in `.azure/<env name>/.env` but are **not** automatically loaded into your shell environment. Open that file to look up the values you need, or source them first:
>
> ```PowerShell
> # Load all azd env vars into the current shell
> azd env get-values | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"')) } }
> ```

```PowerShell
./src/weather-app/New-Tenant.ps1 `
    -TenantNames "zach-c" `
    -AcrName $env:ACR_NAME `
    -IdentityProviderHostname $env:IDENTITY_PROVIDER_HOSTNAME

git add src/tenants/ && git commit -m "Add tenant zach-c" && git push
```

If the new tenant uses a hostname not covered by the existing server certificate SANs, re-run `Initialize-Certs.ps1` to regenerate and upload certificates (it auto-discovers hostnames from tenant values files):

```PowerShell
& src/weather-app/Initialize-Certs.ps1
```

### Managing tenants

```PowerShell
# List all ArgoCD-managed tenant applications
kubectl get applications -n argocd | Select-String "tenant-"

# Remove a tenant, delete the values file, commit, and push
Remove-Item -Recurse src/tenants/zach-c
git add -A && git commit -m "Remove tenant zach-c" && git push
```
