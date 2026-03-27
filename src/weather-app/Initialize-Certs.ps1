#Requires -Version 7.5
<#
.SYNOPSIS
    Generates root CA, server, and client certificates, installs them on the local Windows machine,
    and uploads them to Azure Key Vault.
    Idempotent: skips generation if existing certs on disk and in Key Vault all match.

.DESCRIPTION
    Responsibilities:
      1. Generate root CA (only if missing).
      2. Generate/re-sign server certificate when hostnames change (CA is preserved).
      3. Generate client mTLS certificate (only if missing).
      4. Install root CA and client cert to local Windows cert stores.
      5. Upload root CA, server cert, and server key to Azure Key Vault.

    Hostnames are discovered from src/tenants/*/values.yaml (appHostname field)
    plus the IDENTITY_PROVIDER_HOSTNAME env var.

    This script does NOT create Kubernetes secrets or restart deployments.
    The Secrets Store CSI driver handles syncing Key Vault → K8s Secrets.
#>
param(
    [string[]]$Hostnames,
    [string]$KeyVaultName = $env:KEY_VAULT_NAME,
    [string]$PfxPassword = "ChangeMePlease123!"
)

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot

# --- Discover hostnames if not explicitly provided ---
if (-not $Hostnames -or $Hostnames.Count -eq 0) {
    $discoveredHostnames = @()

    if ($env:IDENTITY_PROVIDER_HOSTNAME) {
        $discoveredHostnames += $env:IDENTITY_PROVIDER_HOSTNAME
    }

    $tenantsDir = Join-Path $PSScriptRoot ".." "tenants"
    if (Test-Path $tenantsDir) {
        Get-ChildItem -Path $tenantsDir -Filter "values.yaml" -Recurse -File | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            if ($content -match 'appHostname:\s*"([^"]+)"') {
                $discoveredHostnames += $Matches[1]
            }
        }
    }

    $Hostnames = $discoveredHostnames | Select-Object -Unique
}

if ($Hostnames.Count -eq 0) {
    Pop-Location
    throw "No hostnames provided or discovered. Pass -Hostnames or set IDENTITY_PROVIDER_HOSTNAME and create tenant values files."
}

if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
    Pop-Location
    throw "KeyVaultName is required. Set KEY_VAULT_NAME environment variable or pass it as a parameter."
}

$sortedHostnames = $Hostnames | Sort-Object
Write-Host "=== Certificate hostnames ===" -ForegroundColor Cyan
$sortedHostnames | ForEach-Object { Write-Host ("{0}{1}" -f "  ", $_) -ForegroundColor DarkGray }

# --- Helper: get the SHA-256 thumbprint of a PEM certificate file ---
function Get-PemThumbprint([string]$Path) {
    openssl x509 -in $Path -noout -fingerprint -sha256 2>$null |
        ForEach-Object { ($_ -replace 'sha256 Fingerprint=', '' -replace ':', '').Trim() }
}

# --- Helper: SHA-256 hash of a local file's raw bytes ---
function Get-FileContentHash([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fullPath = (Resolve-Path $Path).Path
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
}

# --- Helper: SHA-256 hash of a Key Vault secret's value ---
function Get-KvSecretHash([string]$VaultName, [string]$SecretName) {
    $value = az keyvault secret show --vault-name $VaultName --name $SecretName --query "value" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($value)
    return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
}

# --- Helper: get sorted SAN hostnames from an existing cert ---
function Get-CertSanHostnames([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    $sanOutput = (openssl x509 -in $Path -noout -ext subjectAltName 2>$null) -join ' '
    $dnsNames = [regex]::Matches($sanOutput, 'DNS:([^\s,]+)') | ForEach-Object { $_.Groups[1].Value }
    return ($dnsNames | Sort-Object)
}

# --- Determine what needs regeneration ---
$caFiles = @("ca.key", "ca.crt")
$serverFiles = @("gateway-tls.key", "gateway-tls.crt")
$clientFiles = @("mtls-client.key", "mtls-client.crt", "mtls-client.pfx")

$needsCa     = ($caFiles | Where-Object { -not (Test-Path $_) }).Count -gt 0
$needsClient = ($clientFiles | Where-Object { -not (Test-Path $_) }).Count -gt 0

# Server cert needs regeneration if files are missing OR if SANs don't match
$needsServer = ($serverFiles | Where-Object { -not (Test-Path $_) }).Count -gt 0
if (-not $needsServer) {
    $existingSans = Get-CertSanHostnames "gateway-tls.crt"
    $desiredSans  = $sortedHostnames
    $sansMatch    = ($null -eq (Compare-Object $existingSans $desiredSans -SyncWindow 0))
    if (-not $sansMatch) {
        Write-Host "  Server cert SANs changed. Will re-sign with existing CA." -ForegroundColor Yellow
        Write-Host ("{0}Current: {1}" -f "    ", ($existingSans -join ', ')) -ForegroundColor DarkGray
        Write-Host ("{0}Desired: {1}" -f "    ", ($desiredSans -join ', ')) -ForegroundColor DarkGray
        $needsServer = $true
    }
}

# If CA needs regen, everything below it must also regen
if ($needsCa) {
    $needsServer = $true
    $needsClient = $true
}

# --- Generate Root CA (only if missing) ---
if ($needsCa) {
    Write-Host "=== Generating Root CA ===" -ForegroundColor Cyan
    openssl genrsa -out ca.key 2048
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 1024 -out ca.crt `
        -subj "/C=US/ST=North Dakota/L=Fargo/O=Contoso/CN=contoso-root"
} else {
    Write-Host "=== Root CA exists, skipping ===" -ForegroundColor Green
}

# --- Generate Server Certificate (when hostnames change or files missing) ---
if ($needsServer) {
    Write-Host "=== Generating Server Certificate ===" -ForegroundColor Cyan
    $sanList = ($sortedHostnames | ForEach-Object { "DNS:$_" }) -join ','
    openssl genrsa -out gateway-tls.key 2048
    openssl req -new -key gateway-tls.key -out gateway-tls.csr `
        -subj "/C=US/ST=North Dakota/L=Fargo/O=Contoso/CN=$($sortedHostnames[0])" `
        -addext "subjectAltName=$sanList"
    openssl x509 -req -in gateway-tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial `
        -out gateway-tls.crt -days 1024 -sha256 -copy_extensions copyall
} else {
    Write-Host "=== Server certificate SANs match, skipping ===" -ForegroundColor Green
}

# --- Generate Client Certificate (only if missing) ---
if ($needsClient) {
    Write-Host "=== Generating Client Certificate ===" -ForegroundColor Cyan
    openssl genrsa -out mtls-client.key 2048
    openssl req -new -key mtls-client.key -out mtls-client.csr `
        -subj "/C=US/ST=North Dakota/L=Fargo/O=Contoso/CN=contoso-client"
    openssl x509 -req -in mtls-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial `
        -out mtls-client.crt -days 1024 -sha256

    Write-Host "=== Creating PFX bundle ===" -ForegroundColor Cyan
    openssl pkcs12 -export -out mtls-client.pfx -inkey mtls-client.key -in mtls-client.crt -certfile ca.crt `
        -passout "pass:$PfxPassword"
} else {
    Write-Host "=== Client certificate exists, skipping ===" -ForegroundColor Green
}

# --- Install to Windows cert stores (only if missing) ---
$localRootThumbprint = Get-PemThumbprint "ca.crt"
$storeRoot = Get-ChildItem Cert:\CurrentUser\Root | Where-Object { $_.Thumbprint -eq $localRootThumbprint }
if (-not $storeRoot) {
    Write-Host "=== Installing Root CA to Trusted Root store ===" -ForegroundColor Cyan
    Import-Certificate -FilePath .\ca.crt -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
} else {
    Write-Host "=== Root CA already in Trusted Root store,  skipping ===" -ForegroundColor Green
}

$localClientThumbprint = Get-PemThumbprint "mtls-client.crt"
$storeClient = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $localClientThumbprint }
if (-not $storeClient) {
    Write-Host "=== Installing Client Certificate to Personal store ===" -ForegroundColor Cyan
    $securePassword = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force
    Import-PfxCertificate -FilePath .\mtls-client.pfx -CertStoreLocation Cert:\CurrentUser\My -Password $securePassword | Out-Null
} else {
    Write-Host "=== Client cert already in Personal store,  skipping ===" -ForegroundColor Green
}

# --- Sync to Azure Key Vault (only if they differ from local files) ---
$localRootCrtHash    = Get-FileContentHash "ca.crt"
$localServerCertHash = Get-FileContentHash "gateway-tls.crt"
$localServerKeyHash  = Get-FileContentHash "gateway-tls.key"

$kvRootCaHash    = Get-KvSecretHash $KeyVaultName "root-ca-cert"
$kvServerCertHash = Get-KvSecretHash $KeyVaultName "gateway-tls-crt"
$kvServerKeyHash  = Get-KvSecretHash $KeyVaultName "gateway-tls-key"

if ($localRootCrtHash -ne $kvRootCaHash) {
    Write-Host "=== Uploading root CA to Key Vault ===" -ForegroundColor Cyan
    az keyvault secret set --vault-name $KeyVaultName --name "root-ca-cert" --file ca.crt --encoding utf-8 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload root-ca-cert to Key Vault" }
} else {
    Write-Host "=== root-ca-cert already matches in Key Vault,  skipping ===" -ForegroundColor Green
}

if ($localServerCertHash -ne $kvServerCertHash) {
    Write-Host "=== Uploading server certificate to Key Vault ===" -ForegroundColor Cyan
    az keyvault secret set --vault-name $KeyVaultName --name "gateway-tls-crt" --file gateway-tls.crt --encoding utf-8 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload gateway-tls-crt to Key Vault" }
} else {
    Write-Host "=== gateway-tls-crt already matches in Key Vault,  skipping ===" -ForegroundColor Green
}

if ($localServerKeyHash -ne $kvServerKeyHash) {
    Write-Host "=== Uploading server key to Key Vault ===" -ForegroundColor Cyan
    az keyvault secret set --vault-name $KeyVaultName --name "gateway-tls-key" --file gateway-tls.key --encoding utf-8 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload gateway-tls-key to Key Vault" }
} else {
    Write-Host "=== gateway-tls-key already matches in Key Vault,  skipping ===" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Certificates are in place." -ForegroundColor Green
Write-Host "Root CA thumbprint:     $localRootThumbprint"
Write-Host "Client cert thumbprint: $localClientThumbprint"
Write-Host ("{0}SAN hostnames: {1}" -f "  ", ($sortedHostnames -join ', ')) -ForegroundColor DarkGray
Write-Host ""
Write-Host "If certs were regenerated, restart your browser." -ForegroundColor Yellow

Pop-Location
