#Requires -Version 7.5
<#
.SYNOPSIS
    Waits for the Azure ALB Gateway to receive an external IP address and returns it.

.PARAMETER GatewayName
    Name of the Gateway resource.

.PARAMETER Namespace
    Kubernetes namespace of the Gateway.

.PARAMETER TimeoutSeconds
    Maximum time to wait for the IP to be assigned.

.PARAMETER PollIntervalSeconds
    Seconds between polling attempts.

.EXAMPLE
    $ip = & .\Get-GatewayIpAddress.ps1
    Write-Host "Gateway IP: $ip"
#>
param(
    [string]$GatewayName = "agc-gateway",
    [string]$Namespace = "infra",
    [int]$TimeoutSeconds = 600,
    [int]$PollIntervalSeconds = 10
)

$ErrorActionPreference = "Stop"

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)

while ((Get-Date) -lt $deadline) {
    $address = kubectl get gateway $GatewayName -n $Namespace `
        -o jsonpath='{.status.addresses[0].value}' 2>$null

    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($address)) {
        # If the address is already an IP, return it directly
        if ($address -match '^\d{1,3}(\.\d{1,3}){3}$') {
            return $address
        }

        # Otherwise it's an FQDN so we need to resolve to an IP
        Write-Host "  Gateway address is FQDN: $address,  resolving to IP..." -ForegroundColor DarkGray
        try {
            $resolved = [System.Net.Dns]::GetHostAddresses($address) |
                Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                Select-Object -First 1

            if ($resolved) {
                return $resolved.IPAddressToString
            }
        } catch {
            Write-Host "  DNS resolution failed, retrying..." -ForegroundColor DarkGray
        }
    }

    $remaining = [math]::Round(($deadline - (Get-Date)).TotalSeconds)
    Write-Host "  Waiting for Gateway '$GatewayName' IP... (${remaining}s remaining)" -ForegroundColor DarkGray
    Start-Sleep -Seconds $PollIntervalSeconds
}

throw "Timed out after ${TimeoutSeconds}s waiting for Gateway '$GatewayName' in namespace '$Namespace' to receive a resolvable IP address."
