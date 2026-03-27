#Requires -Version 7.5
<#
.SYNOPSIS
    Post-deploy hook: bootstraps the ArgoCD App of Apps.
    Runs automatically after ArgoCD is deployed via `azd deploy`.

.DESCRIPTION
    Required azd environment variables (set via `azd env set`):
      KUBELET_IDENTITY_CLIENT_ID - (from terraform output)
      KEY_VAULT_NAME             - (from terraform output)
      AZURE_TENANT_ID                  - (from terraform output)
      AKS_LB_SNET_ID            - (from terraform output)
      IDENTITY_PROVIDER_HOSTNAME - e.g. "zach-keycloak.duckdns.org"
      ACR_NAME                   - (from terraform output)
#>

$ErrorActionPreference = "Stop"

$repoRoot   = Join-Path $PSScriptRoot ".."
$tenantsDir = Join-Path $repoRoot "src" "tenants"

# --- Validate required env vars ---
$requiredVars = @(
    "KUBELET_IDENTITY_CLIENT_ID",
    "KEY_VAULT_NAME",
    "AZURE_TENANT_ID",
    "AKS_LB_SNET_ID",
    "IDENTITY_PROVIDER_HOSTNAME",
    "ACR_NAME"
)
$missing = $requiredVars | Where-Object { -not [Environment]::GetEnvironmentVariable($_) }
if ($missing) {
    Write-Error "Missing required azd environment variables: $($missing -join ', '). Set them with 'azd env set'."
    exit 1
}

# --- Discover tenants from src/tenants/*/values.yaml ---
$tenantValueFiles = Get-ChildItem -Path $tenantsDir -Filter "values.yaml" -Recurse -File
if (-not $tenantValueFiles) {
    Write-Warning "No tenant values files found under $tenantsDir. Run New-Tenant.ps1 to create tenants."
}
$tenantNames = $tenantValueFiles | ForEach-Object { $_.Directory.Name }

# --- Build DuckDNS hostnames from discovered tenants ---
$allHostnames = @($env:IDENTITY_PROVIDER_HOSTNAME)
$allHostnames += $tenantNames | ForEach-Object { "$_.duckdns.org" }

# --- Bootstrap ArgoCD App of Apps ---
Write-Host "=== Bootstrapping ArgoCD App of Apps ===" -ForegroundColor Cyan

$rootApp = [ordered]@{
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata   = [ordered]@{
        name       = "apps"
        namespace  = "argocd"
        finalizers = @("resources-finalizer.argocd.argoproj.io")
    }
    spec       = [ordered]@{
        project     = "default"
        source      = [ordered]@{
            repoURL        = "https://github.com/zachbugay/aks-designs.git"
            path           = "src/apps"
            targetRevision = "HEAD"
            helm           = [ordered]@{
                valuesObject = [ordered]@{
                    infraBase = [ordered]@{
                        kubeletIdentityClientId = $env:KUBELET_IDENTITY_CLIENT_ID
                        keyVaultName            = $env:KEY_VAULT_NAME
                        tenantId                = $env:AZURE_TENANT_ID
                    }
                    gateway   = [ordered]@{
                        aksLbSubnetId            = $env:AKS_LB_SNET_ID
                        identityProviderHostname = $env:IDENTITY_PROVIDER_HOSTNAME
                        duckdns                  = [ordered]@{
                            enabled   = $true
                            hostnames = $allHostnames
                        }
                    }
                }
            }
        }
        destination = [ordered]@{
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
        }
        syncPolicy  = [ordered]@{
            automated = [ordered]@{
                prune    = $true
                selfHeal = $true
            }
        }
    }
} | ConvertTo-Json -Depth 10

$rootAppFile = Join-Path $repoRoot "src" "root-application.json"
$rootApp | Set-Content $rootAppFile -Encoding utf8
Write-Host ("{0}Manifest written to {1}" -f "  ", $rootAppFile) -ForegroundColor DarkGray

kubectl apply -f $rootAppFile
if ($LASTEXITCODE -ne 0) { throw "Failed to create ArgoCD root Application" }
Write-Host ("{0}Root Application 'apps' created. ArgoCD will sync child applications from Git." -f "  ") -ForegroundColor Green
Write-Host ("{0}Tenants: {1}" -f "  ", ($tenantNames -join ', ')) -ForegroundColor DarkGray

Write-Host ""

Write-Host "=== ArgoCD Credentials ===" -ForegroundColor Cyan
$argoPass = kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' |
    ForEach-Object { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
Write-Host "Username: admin" -ForegroundColor Green
Write-Host "Password: $argoPass" -ForegroundColor Green
Write-Host ""
Write-Host "To access the ArgoCD UI, run:" -ForegroundColor Cyan
Write-Host "kubectl port-forward svc/argocd-server -n argocd 8443:443" -ForegroundColor Yellow
Write-Host "Then open https://localhost:8443" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== Post-deploy complete ===" -ForegroundColor Green
