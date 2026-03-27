#Requires -Version 7.5
<#
.SYNOPSIS
    Ensures a valid DuckDNS token is available, prompting the user interactively if
    the token is missing or invalid.

.DESCRIPTION
    1. Checks the DUCKDNS_TOKEN environment variable.
    2. Validates the token against the DuckDNS API using a test hostname.
    3. If the token is missing or invalid, prompts the user for a new one.
    4. Persists the validated token with `azd env set` for future runs.
    5. Returns the validated token string.

.PARAMETER TestHostname
    A *.duckdns.org FQDN owned by the token holder, used to validate the token.
    The subdomain is extracted automatically.

.EXAMPLE
    $token = & .\Get-DuckDnsToken.ps1 -TestHostname "zach-a.duckdns.org"
#>
param(
    [Parameter(Mandatory)]
    [string]$TestHostname
)

$ErrorActionPreference = "Stop"
$duckDnsSuffix = ".duckdns.org"

if (-not $TestHostname.EndsWith($duckDnsSuffix)) {
    throw "TestHostname '$TestHostname' must end with '$duckDnsSuffix'."
}

$testSubdomain = $TestHostname.Substring(0, $TestHostname.Length - $duckDnsSuffix.Length)

function Test-DuckDnsToken {
    param(
        [string]$Token,
        [string]$Subdomain
    )
    $uri = "https://www.duckdns.org/update?domains=$Subdomain&token=$Token&verbose=true"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get
        return $response -match '^OK'
    }
    catch {
        return $false
    }
}

# Check existing token
$token = $env:DUCKDNS_TOKEN

if ($token) {
    Write-Host "  Validating existing DuckDNS token..." -ForegroundColor DarkGray
    if (Test-DuckDnsToken -Token $token -Subdomain $testSubdomain) {
        Write-Host "  DuckDNS token is valid." -ForegroundColor Green
        return $token
    }
    Write-Warning "Existing DuckDNS token is invalid or does not own '$TestHostname'."
}

# Prompt for a new token
$maxAttempts = 3
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    Write-Host ""
    Write-Host "  Enter your DuckDNS token (from https://www.duckdns.org):" -ForegroundColor Yellow
    $newToken = Read-Host "  Token"

    if (-not $newToken) {
        Write-Warning "No token entered."
        continue
    }

    Write-Host "  Validating token..." -ForegroundColor DarkGray
    if (Test-DuckDnsToken -Token $newToken -Subdomain $testSubdomain) {
        Write-Host "  DuckDNS token is valid." -ForegroundColor Green

        # Persist for future azd runs
        azd env set DUCKDNS_TOKEN $newToken
        $env:DUCKDNS_TOKEN = $newToken

        return $newToken
    }

    Write-Warning "Token is invalid or does not own '$TestHostname'. ($attempt/$maxAttempts)"
}

throw "Failed to obtain a valid DuckDNS token after $maxAttempts attempts."
