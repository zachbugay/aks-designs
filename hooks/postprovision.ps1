#Requires -Version 7.5
<#
.SYNOPSIS
    Post-provision hook: gets AKS credentials, initializes TLS certificates,
    and builds container images to ACR.
    Runs automatically after `azd provision`.

.DESCRIPTION
    Required azd environment variables (set via `azd env set`):
      AKS_RESOURCE_GROUP         - (from terraform output)
      AZURE_AKS_CLUSTER_NAME     - (from terraform output)
      ACR_NAME                   - (from terraform output)
      KEY_VAULT_NAME             - (from terraform output)
      DUCKDNS_TOKEN              - DuckDNS API token (https://www.duckdns.org)
#>

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONUTF8 = "1"
chcp 65001 | Out-Null
$env:PYTHONIOENCODING = "utf-8"

function Test-AcrImageExists {
    param([string]$Registry, [string]$Image, [string]$Tag)
    $result = az acr repository show-tags --name $Registry --repository $Image --query "contains(@, '$Tag')" --output tsv 2>$null
    return ($LASTEXITCODE -eq 0 -and $result -eq 'true')
}

function Test-GitChanges {
    param([string]$Path, [string]$MarkerFile)
    if (Test-Path $MarkerFile) {
        $lastSha = Get-Content $MarkerFile -Raw | ForEach-Object { $_.Trim() }
        $diff = git diff --name-only $lastSha HEAD -- $Path 2>$null
        if ($diff) { return $true }
    } else {
        return $true
    }
    $staged = git diff --cached --name-only -- $Path 2>$null
    if ($staged) { return $true }
    $unstaged = git diff --name-only -- $Path 2>$null
    if ($unstaged) { return $true }
    return $false
}

$weatherAppDir = Join-Path $PSScriptRoot ".." "src" "weather-app"
$deployMarkerFile = Join-Path $PSScriptRoot ".last-deploy-sha"

$requiredVars = @(
    "AKS_RESOURCE_GROUP",
    "AZURE_AKS_CLUSTER_NAME",
    "ACR_NAME",
    "KEY_VAULT_NAME",
    "DUCKDNS_TOKEN"
)

$services = @(
    @{
        Name        = "bugay-service-example"
        Image       = "bugay-service-example"
        BuildContext = "$weatherAppDir/Bugay.Service.Example/src/Bugay.Service.Example"
        SourcePath  = "src/weather-app/Bugay.Service.Example"
    },
    @{
        Name        = "bugay-reactapp-example"
        Image       = "bugay-reactapp-example"
        BuildContext = "$weatherAppDir/Bugay.ReactApp.Example"
        SourcePath  = "src/weather-app/Bugay.ReactApp.Example"
    }
)

$missing = $requiredVars | Where-Object { -not [Environment]::GetEnvironmentVariable($_) }
if ($missing) {
    Write-Error "Missing required azd environment variables: $($missing -join ', '). Set them with 'azd env set'."
    exit 1
}

Write-Host "=== Getting AKS credentials ===" -ForegroundColor Cyan
az aks get-credentials `
    --resource-group $env:AKS_RESOURCE_GROUP `
    --name $env:AZURE_AKS_CLUSTER_NAME `
    --overwrite-existing

Write-Host "=== Initializing certificates ===" -ForegroundColor Cyan
& "$weatherAppDir/Initialize-Certs.ps1"
if ($LASTEXITCODE -ne 0) { throw "Initialize-Certs.ps1 failed" }

Write-Host "=== Storing DuckDNS token in Key Vault ===" -ForegroundColor Cyan
az keyvault secret set `
    --vault-name $env:KEY_VAULT_NAME `
    --name duckdns-token `
    --value $env:DUCKDNS_TOKEN `
    --output none
if ($LASTEXITCODE -ne 0) { throw "Failed to store DuckDNS token in Key Vault" }
Write-Host "  Secret 'duckdns-token' stored in Key Vault '$($env:KEY_VAULT_NAME)'." -ForegroundColor Green

Write-Host "=== Checking container images ===" -ForegroundColor Cyan

foreach ($svc in $services) {
    $imageExists = Test-AcrImageExists -Registry $env:ACR_NAME -Image $svc.Image -Tag "latest"
    $hasChanges  = Test-GitChanges -Path $svc.SourcePath -MarkerFile $deployMarkerFile

    if (-not $imageExists) {
        Write-Host "=== Image '$($svc.Image)' not found in ACR, building ===" -ForegroundColor Yellow
    } elseif ($hasChanges -and $imageExists) {
        if (-not (Test-Path $deployMarkerFile)) {
            Write-Host "=== Image '$($svc.Image)' exists, no deploy marker, skipping build ===" -ForegroundColor Green
            continue
        }
        Write-Host "=== Changes detected in '$($svc.Name)', rebuilding ===" -ForegroundColor Yellow
    } else {
        Write-Host "=== No changes in '$($svc.Name)', skipping ACR build ===" -ForegroundColor Green
        continue
    }

    az acr build `
        --registry $env:ACR_NAME `
        --image "$($svc.Image):latest" `
        --platform linux/amd64 `
        --no-logs `
        $svc.BuildContext
    if ($LASTEXITCODE -ne 0) { throw "ACR build for $($svc.Name) failed" }
}

# --- Update tenant values.yaml acrName from current ACR_NAME ---
Write-Host "=== Updating tenant acrName values ===" -ForegroundColor Cyan
$tenantsDir = Join-Path $PSScriptRoot ".." "src" "tenants"
$tenantValueFiles = Get-ChildItem -Path $tenantsDir -Filter "values.yaml" -Recurse -File
foreach ($file in $tenantValueFiles) {
    $content = Get-Content $file.FullName -Raw
    $updated = $content -replace '(?m)^(acrName:\s*").*(")', "`${1}$($env:ACR_NAME)`${2}"
    if ($content -ne $updated) {
        $updated | Set-Content $file.FullName -NoNewline -Encoding utf8
        Write-Host "Updated acrName in $($file.FullName)" -ForegroundColor Green
    } else {
        Write-Host "acrName already current in $($file.FullName)" -ForegroundColor DarkGray
    }
}

$currentSha = git rev-parse HEAD 2>$null
if ($currentSha) {
    $currentSha | Set-Content $deployMarkerFile -NoNewline
}

Write-Host ""
Write-Host "=== Post-provision complete ===" -ForegroundColor Green
