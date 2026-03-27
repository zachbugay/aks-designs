#Requires -Version 7.5
<#
.SYNOPSIS
    Creates tenant values files for ArgoCD to discover and deploy.

.DESCRIPTION
    Creates a values.yaml under src/tenants/<name>/ for each specified tenant.
    Once committed and pushed, ArgoCD's Git file generator will detect the new
    tenant and deploy it automatically.

.PARAMETER TenantNames
    One or more tenant names to create (e.g. "zach-a", "zach-b").

.PARAMETER AcrName
    The Azure Container Registry name (e.g. "devcrentappsle4j001").

.PARAMETER IdentityProviderHostname
    The Keycloak hostname (e.g. "zach-keycloak.duckdns.org").

.EXAMPLE
    ./src/weather-app/New-Tenant.ps1 -TenantNames "zach-a", "zach-b" -AcrName "devcrentappsle4j001" -IdentityProviderHostname "zach-keycloak.duckdns.org"

.EXAMPLE
    ./src/weather-app/New-Tenant.ps1 "tenant-1" -AcrName "myacr" -IdentityProviderHostname "keycloak.example.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$TenantNames,

    [Parameter(Mandatory)]
    [string]$AcrName,

    [Parameter(Mandatory)]
    [string]$IdentityProviderHostname
)

$ErrorActionPreference = "Stop"

$tenantsDir = Join-Path $PSScriptRoot ".." "tenants"

# --- Create tenant values files ---
foreach ($tenant in $TenantNames) {
    $tenantDir  = Join-Path $tenantsDir $tenant
    $valuesFile = Join-Path $tenantDir "values.yaml"

    if (-not (Test-Path $tenantDir)) {
        New-Item -ItemType Directory -Path $tenantDir -Force | Out-Null
    }

    $values = @"
tenantName: "$tenant"
acrName: "$AcrName"
appHostname: "$tenant.duckdns.org"
identityProviderHostname: "$IdentityProviderHostname"
"@

    $existing = if (Test-Path $valuesFile) { Get-Content $valuesFile -Raw } else { "" }
    if ($existing.TrimEnd() -ne $values.TrimEnd()) {
        $values | Set-Content $valuesFile -NoNewline
        Write-Host ("{0}Created {1}/values.yaml" -f "  ", $tenant) -ForegroundColor Green
    } else {
        Write-Host ("{0}{1}/values.yaml already up to date" -f "  ", $tenant) -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Commit and push to deploy. ArgoCD will detect the new tenant(s) automatically." -ForegroundColor Cyan
