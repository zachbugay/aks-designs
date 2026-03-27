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
| `AKS_NODE_POOL_VM_SIZE`      | Yes      | VM size for AKS node pool (e.g., `Standard_D4as_v7`)                                                                               |
| `ADMIN_OBJECT_IDS`           | Yes      | Comma-separated Entra ID group object IDs for AKS admin access                                                                     |
| `ALERT_EMAIL`                | Yes      | Email address for AKS alert notifications                                                                                          |
| `AZURE_VPN_GATEWAY`          | Yes      | Whether to enable an Azure VPN Gateway or not.                                                                                     |
| `AZURE_FIREWALL`             | Yes      | JSON enabling the Azure Firewall with a specific SKU.                                                                              |
| `AGW_TRUSTED_ROOT_CA_BASE64` | No       | Base64 PEM of the demo CA. Empty on first `azd up`; see [Backend TLS trusted root bootstrap](#backend-tls-trusted-root-bootstrap). |

## Quick Start

```PowerShell
# Create the environment
azd env new nonprod

# --- Infrastructure settings ---
azd env set AKS_NODE_POOL_VM_SIZE "Standard_D4as_v7"
azd env set AZURE_ENV_NAME "nonprod"
azd env set AZURE_WORKLOAD_ENV_NAME "dev"
azd env set AZURE_LOCATION "westus3"
azd env set AZURE_SUBSCRIPTION_ID "<your subscription id>"
azd env set AZURE_TENANT_ID "<your tenant id>"
azd env set ADMIN_OBJECT_IDS "<comma-separated group object IDs>"
azd env set ALERT_EMAIL "<your email>"
azd env set AZURE_VPN_GATEWAY "true"
azd env set AZURE_FIREWALL="{\"enabled\":true,\"sku_tier\":\"Standard\",\"sku_name\":\"AZFW_VNet\",\"default_rules\":true}"

# Github Specifics
azd env set GITHUB_REPO_NAME "<your-repo>"
azd env set GITHUB_TOKEN "<your-token>"
azd env set GITHUB_USERNAME "<your-username>"

# Choose between Basic, Standard, or Premium
```

## Backend TLS trusted root bootstrap

This is a **one-time** step, required after the first `azd up`.

### Why

The demo CA is minted inside the cluster by cert-manager
(`k8s/infrastructure/configs/cert-manager/demo-ca-certificate.yaml`), so its private key never
exists in Terraform state. It cannot be created in Key Vault: `azurerm_key_vault_certificate`
exposes no `basic_constraints` argument, and Key Vault's `Self` issuer always emits `CA:FALSE`,
which cert-manager's CA issuer rejects.

That CA signs the certificates the in-cluster Istio gateway presents on port 443. The Application
Gateway talks to that gateway with `backend_protocol = "Https"`, and
[Application Gateway v2 requires the backend's root certificate to be uploaded](https://learn.microsoft.com/azure/application-gateway/ssl-overview#end-to-end-tls-with-the-v2-sku)
whenever it is not a well-known public CA.

Because the CA only exists after Flux reconciles, and the Application Gateway is created by
Terraform, the root has to be supplied on a second apply.

Until you complete this, the Application Gateway backend pool reports **Unhealthy** with:

> The root certificate of the server certificate used by the backend does not match the trusted
> root certificate added to the application gateway.

### Steps

```bash
# 1. Provision. The Application Gateway comes up without a trusted root; backends are Unhealthy.
azd up

# 2. Wait for Flux to reconcile and cert-manager to issue the CA.
kubectl wait --for=condition=Ready certificate/demo-ca -n cert-manager --timeout=5m

# 3. Capture the CA public certificate. Secret data is already base64 encoded, so pass it verbatim.
azd env set AGW_TRUSTED_ROOT_CA_BASE64 \
  "$(kubectl get secret demo-ca -n cert-manager -o jsonpath='{.data.ca\.crt}')"

# 4. Re-apply to upload the trusted root.
azd provision
```

Verify the backends are healthy:

```bash
# Set variables
AGW_RESOURCE_GROUP="<agw resource group name>"
AGW_NAME="<agw name>"

az network application-gateway show-backend-health \
  --resource-group "$AGW_RESOURCE_GROUP" \
  --name "$AGW_NAME" \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].health"
```

#### Troubleshooting

- Make sure `demo-gateway-approuting-istio` service creates an internal load balancer and assigns an internal IP address.
- Make sure the application gateway is using that ILB private IP as the backend.

### When you need to repeat it

Only if the CA changes. `demo-ca-certificate.yaml` pins `duration: 2160h` (90days) and
`privateKey.rotationPolicy: Never` precisely so that it does not. Note that cert-manager 1.18+
[defaults `rotationPolicy` to `Always`](https://cert-manager.io/docs/releases/upgrading/upgrading-1.17-1.18/);
leaving it at the default would rotate the CA key on every renewal and silently break the
Application Gateway trusted root. If you ever delete the `demo-ca` Secret or shorten the duration,
repeat steps 2-4.
