#Requires -Version 7.5
<#
.SYNOPSIS
    Updates DuckDNS records to point the given hostnames at the specified IP address.

.PARAMETER Token
    DuckDNS API token.

.PARAMETER Hostnames
    One or more FQDNs ending in .duckdns.org (e.g. "zach-a.duckdns.org").
    The subdomain prefix is extracted automatically.

.PARAMETER IpAddress
    The IPv4 address to set for the DNS records.

.EXAMPLE
    .\Update-DuckDns.ps1 -Token $env:DUCKDNS_TOKEN `
        -Hostnames "zach-a.duckdns.org","zach-keycloak.duckdns.org" `
        -IpAddress "20.30.40.50"
#>
param(
    [Parameter(Mandatory)]
    [string]$Token,

    [Parameter(Mandatory)]
    [string[]]$Hostnames,

    [Parameter(Mandatory)]
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$IpAddress
)

$ErrorActionPreference = "Stop"
$duckDnsSuffix = ".duckdns.org"

$subdomains = $Hostnames | ForEach-Object {
    if (-not $_.EndsWith($duckDnsSuffix)) {
        throw "Hostname '$_' does not end with '$duckDnsSuffix'. DuckDNS can only manage *.duckdns.org domains."
    }
    $_.Substring(0, $_.Length - $duckDnsSuffix.Length)
}

$domainList = $subdomains -join ','
$uri = "https://www.duckdns.org/update?domains=$domainList&token=$Token&ip=$IpAddress"

Write-Host "  Updating DuckDNS: $($subdomains -join ', ') -> $IpAddress" -ForegroundColor DarkGray
$response = Invoke-RestMethod -Uri $uri -Method Get

if ($response -notmatch '^OK') {
    throw "DuckDNS update failed. Response: $response"
}

Write-Host "  DuckDNS updated successfully." -ForegroundColor Green
