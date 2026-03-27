#Requires -Version 7.5
<#
.SYNOPSIS
    Removes all generated certificates from disk and uninstalls them from Windows cert stores.
#>

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot

Write-Host "=== Removing certificates from Windows store ===" -ForegroundColor Cyan

# Remove client cert from Personal store
$clientCerts = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match "contoso-client" }
foreach ($cert in $clientCerts) {
    Write-Host "  Removing client cert: $($cert.Thumbprint)"
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
}

# Remove root CA from Trusted Root store
$rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new("Root", "CurrentUser")
$rootStore.Open("ReadWrite")
$rootCerts = $rootStore.Certificates | Where-Object { $_.Subject -match "contoso-root" }
foreach ($cert in $rootCerts) {
    Write-Host "  Removing root CA: $($cert.Thumbprint)"
    $rootStore.Remove($cert)
}
$rootStore.Close()

Write-Host "=== Removing certificate files from disk ===" -ForegroundColor Cyan
$filesToRemove = @(
    "ca.key", "ca.crt", "ca.srl",
    "gateway-tls.key", "gateway-tls.crt", "gateway-tls.csr",
    "mtls-client.key", "mtls-client.crt", "mtls-client.csr", "mtls-client.pfx",
    "gateway-tls-secret.yaml", "ca-bundle-secret.yaml"
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "  Deleted: $file"
    }
}

Write-Host ""
Write-Host "Cleanup complete. All certificates removed." -ForegroundColor Green

Pop-Location
