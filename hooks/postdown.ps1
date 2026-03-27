#Requires -Version 7.5
<#
.SYNOPSIS
    Post-down hook: cleans up Kubernetes resources, certificates, and local
    kubeconfig context after `azd down`.

.DESCRIPTION
    Required azd environment variables (set via `azd env set`):
      AKS_RESOURCE_GROUP    - (from terraform output)
      AZURE_AKS_CLUSTER_NAME      - (from terraform output)
#>

$ErrorActionPreference = "Stop"

$weatherAppDir = Join-Path $PSScriptRoot ".." "src" "weather-app"

# --- Remove certificates and Kubernetes TLS secrets ---
Write-Host "=== Removing certificates ===" -ForegroundColor Cyan
& "$weatherAppDir/Remove-Certs.ps1"
if ($LASTEXITCODE -ne 0) { Write-Warning "Remove-Certs.ps1 returned a non-zero exit code" }

# --- Remove kubeconfig context ---
Write-Host "=== Cleaning up kubeconfig context ===" -ForegroundColor Cyan
if ($env:AZURE_AKS_CLUSTER_NAME) {
    kubectl config delete-context $env:AZURE_AKS_CLUSTER_NAME 2>$null
    kubectl config delete-cluster $env:AZURE_AKS_CLUSTER_NAME 2>$null
    kubectl config delete-user "clusterUser_$($env:AKS_RESOURCE_GROUP)_$($env:AZURE_AKS_CLUSTER_NAME)" 2>$null
    Write-Host "  Removed kubeconfig entries for $($env:AZURE_AKS_CLUSTER_NAME)" -ForegroundColor Green
} else {
    Write-Warning "AZURE_AKS_CLUSTER_NAME not set; skipping kubeconfig cleanup"
}

Write-Host ""
Write-Host "=== Post-down cleanup complete ===" -ForegroundColor Green
