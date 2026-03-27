#Requires -Version 7.5
<#
.SYNOPSIS
    Creates a Keycloak realm and registers clients with protocol mappers.

.PARAMETER RealmName
    Name of the realm to create (e.g. "zach-a", "zach-b").

.PARAMETER KeycloakBaseUrl
    Base URL of the Keycloak instance (no trailing slash).

.PARAMETER AdminUser
    Keycloak bootstrap admin username.

.PARAMETER AdminPassword
    Keycloak bootstrap admin password.

.EXAMPLE
    # Create realm zach-a via port-forward
    kubectl port-forward svc/keycloak 8080:8080
    .\Initialize-KeycloakRealm.ps1 -RealmName zach-a

.EXAMPLE
    # Create realm zach-b via external hostname
    .\Initialize-KeycloakRealm.ps1 -RealmName zach-b -KeycloakBaseUrl "https://zach-keycloak.duckdns.org"
#>
param(
    [Parameter(Mandatory)]
    [string]$RealmName,
    [string]$AppHostname = $env:APP_HOSTNAME,
    [string]$KeycloakBaseUrl = "http://localhost:8080",
    [string]$AdminUser       = "admin",
    [string]$AdminPassword   = "admin",
    [string]$ClientCertPfx   = "$PSScriptRoot\mtls-client.pfx",
    [string]$PfxPassword     = "ChangeMePlease123!"
)

$ErrorActionPreference = "Stop"
$KeycloakBaseUrl = $KeycloakBaseUrl.TrimEnd('/')

$clientCert = $null
if ($KeycloakBaseUrl -match '^https://' -and (Test-Path $ClientCertPfx)) {
    $secPfxPass = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force
    $clientCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        (Resolve-Path $ClientCertPfx).Path, $secPfxPass)
    Write-Host "  Using client certificate: $($clientCert.Subject)" -ForegroundColor DarkGray
}

function Invoke-Keycloak {
    param(
        [string]$Method,
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers
    )
    $params = @{
        Method               = $Method
        Uri                  = $Uri
        Headers              = $Headers
        ContentType          = "application/json"
    }
    if ($script:clientCert) {
        $params.Certificate = $script:clientCert
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    Invoke-RestMethod @params
}

function Get-KeycloakToken {
    param(
        [string]$BaseUrl,
        [string]$User,
        [string]$Password
    )
    $tokenParams = @{
        Method      = 'Post'
        Uri         = "$BaseUrl/realms/master/protocol/openid-connect/token"
        ContentType = 'application/x-www-form-urlencoded'
    }
    if ($script:clientCert) { $tokenParams.Certificate = $script:clientCert }
    $response = Invoke-RestMethod @tokenParams -Body @{
        grant_type = "password"
        client_id  = "admin-cli"
        username   = $User
        password   = $Password
    }
    return @{ Authorization = "Bearer $($response.access_token)" }
}

function New-KeycloakRealm {
    param(
        [string]$BaseUrl,
        [string]$Realm,
        [hashtable]$AuthHeaders
    )
    Write-Host "`n=== Creating realm '$Realm' ===" -ForegroundColor Cyan
    $existing = Invoke-Keycloak -Method Get -Uri "$BaseUrl/admin/realms" -Headers $AuthHeaders
    if ($existing.realm -contains $Realm) {
        Write-Host "Realm '$Realm' already exists - skipping." -ForegroundColor Yellow
        return
    }
    Invoke-Keycloak -Method Post -Uri "$BaseUrl/admin/realms" -Headers $AuthHeaders `
        -Body @{ realm = $Realm; enabled = $true } | Out-Null
    Write-Host "Realm '$Realm' created." -ForegroundColor Green
}

function New-KeycloakClient {
    <#
    .SYNOPSIS
        Creates a client in the given realm. Returns the internal UUID.
    #>
    param(
        [string]$BaseUrl,
        [string]$Realm,
        [hashtable]$AuthHeaders,
        [hashtable]$ClientPayload
    )
    $clientId = $ClientPayload.clientId
    Write-Host "`n=== Creating client '$clientId' ===" -ForegroundColor Cyan

    $existing = Invoke-Keycloak -Method Get `
        -Uri "$BaseUrl/admin/realms/$Realm/clients?clientId=$clientId" -Headers $AuthHeaders

    if ($existing.Count -gt 0) {
        Write-Host "Client '$clientId' already exists - skipping." -ForegroundColor Yellow
        return $existing[0].id
    }

    Invoke-Keycloak -Method Post `
        -Uri "$BaseUrl/admin/realms/$Realm/clients" -Headers $AuthHeaders `
        -Body $ClientPayload | Out-Null

    $created = Invoke-Keycloak -Method Get `
        -Uri "$BaseUrl/admin/realms/$Realm/clients?clientId=$clientId" -Headers $AuthHeaders
    $internalId = $created[0].id
    Write-Host "Client '$clientId' created (id: $internalId)." -ForegroundColor Green
    return $internalId
}

function New-KeycloakProtocolMapper {
    param(
        [string]$BaseUrl,
        [string]$Realm,
        [hashtable]$AuthHeaders,
        [string]$ClientInternalId,
        [string]$ClientDisplayName,
        [hashtable]$MapperPayload
    )
    $mapperName = $MapperPayload.name
    Write-Host "`n=== Adding mapper '$mapperName' to '$ClientDisplayName' ===" -ForegroundColor Cyan

    $existing = Invoke-Keycloak -Method Get `
        -Uri "$BaseUrl/admin/realms/$Realm/clients/$ClientInternalId/protocol-mappers/models" `
        -Headers $AuthHeaders

    if ($existing | Where-Object { $_.name -eq $mapperName }) {
        Write-Host "Mapper '$mapperName' already exists - skipping." -ForegroundColor Yellow
        return
    }

    Invoke-Keycloak -Method Post `
        -Uri "$BaseUrl/admin/realms/$Realm/clients/$ClientInternalId/protocol-mappers/models" `
        -Headers $AuthHeaders -Body $MapperPayload | Out-Null
    Write-Host "Mapper '$mapperName' created." -ForegroundColor Green
}

function Get-KeycloakClientSecret {
    param(
        [string]$BaseUrl,
        [string]$Realm,
        [hashtable]$AuthHeaders,
        [string]$ClientInternalId
    )
    $secret = Invoke-Keycloak -Method Get `
        -Uri "$BaseUrl/admin/realms/$Realm/clients/$ClientInternalId/client-secret" `
        -Headers $AuthHeaders
    return $secret.value
}

function New-KeycloakUser {
    <#
    .SYNOPSIS
        Creates a user in the given realm with a permanent password. Idempotent.
    #>
    param(
        [string]$BaseUrl,
        [string]$Realm,
        [hashtable]$AuthHeaders,
        [hashtable]$UserPayload
    )
    $username = $UserPayload.username
    Write-Host "`n=== Creating user '$username' ===" -ForegroundColor Cyan

    $existing = Invoke-Keycloak -Method Get `
        -Uri "$BaseUrl/admin/realms/$Realm/users?username=$username&exact=true" `
        -Headers $AuthHeaders

    if ($existing.Count -gt 0) {
        Write-Host "User '$username' already exists - skipping." -ForegroundColor Yellow
        return
    }

    Invoke-Keycloak -Method Post `
        -Uri "$BaseUrl/admin/realms/$Realm/users" `
        -Headers $AuthHeaders -Body $UserPayload | Out-Null
    Write-Host "User '$username' created." -ForegroundColor Green
}

$audienceMapper = @{
    name           = "weather-app-aud"
    protocol       = "openid-connect"
    protocolMapper = "oidc-audience-mapper"
    config         = @{
        "included.client.audience"  = "weather-app"
        "id.token.claim"            = "true"
        "access.token.claim"        = "true"
        "introspection.token.claim" = "true"
    }
}

$reactAudienceMapper = @{
    name           = "weather-app-aud"
    protocol       = "openid-connect"
    protocolMapper = "oidc-audience-mapper"
    config         = @{
        "included.client.audience"  = "weather-app"
        "id.token.claim"            = "true"
        "access.token.claim"        = "true"
        "introspection.token.claim" = "true"
    }
}

$redirectUris = @(
    "http://localhost:5713"
    "https://$AppHostname"
)

$weatherAppPayload = @{
    clientId                  = "weather-app"
    name                      = "Weather App"
    enabled                   = $true
    publicClient              = $false
    clientAuthenticatorType   = "client-secret"
    standardFlowEnabled       = $true
    serviceAccountsEnabled    = $true
    redirectUris              = @("/*")
    webOrigins                = @("/*")
    directAccessGrantsEnabled = $false
    implicitFlowEnabled       = $false
}

$reactAppPayload = @{
    clientId                  = "react-app"
    name                      = "React App"
    enabled                   = $true
    publicClient              = $true
    standardFlowEnabled       = $true
    directAccessGrantsEnabled = $false
    implicitFlowEnabled       = $false
    serviceAccountsEnabled    = $false
    frontchannelLogout        = $true
    redirectUris              = @($redirectUris | ForEach-Object { "$_/*" })
    webOrigins                = $redirectUris
    attributes                = @{
        "pkce.code.challenge.method"                = "S256"
        "oauth2.device.authorization.grant.enabled" = "true"
        "post.logout.redirect.uris"                 = ($redirectUris | ForEach-Object { "$_/*" }) -join "##"
        "frontchannel.logout.session.required"      = "true"
    }
}

Write-Host "=== Authenticating to Keycloak ===" -ForegroundColor Cyan
$authHeaders = Get-KeycloakToken -BaseUrl $KeycloakBaseUrl -User $AdminUser -Password $AdminPassword
Write-Host "  Authenticated as '$AdminUser'" -ForegroundColor Green

# Realm
New-KeycloakRealm -BaseUrl $KeycloakBaseUrl -Realm $RealmName -AuthHeaders $authHeaders

# weather-app
$weatherId = New-KeycloakClient -BaseUrl $KeycloakBaseUrl -Realm $RealmName `
    -AuthHeaders $authHeaders -ClientPayload $weatherAppPayload
$weatherSecret = Get-KeycloakClientSecret -BaseUrl $KeycloakBaseUrl -Realm $RealmName `
    -AuthHeaders $authHeaders -ClientInternalId $weatherId
Write-Host ("{0,-15} {1}" -f "Client ID:", "weather-app") -ForegroundColor White
Write-Host ("{0,-15} {1}" -f "Client Secret:", $weatherSecret) -ForegroundColor White

New-KeycloakProtocolMapper -BaseUrl $KeycloakBaseUrl -Realm $RealmName `
    -AuthHeaders $authHeaders -ClientInternalId $weatherId `
    -ClientDisplayName "weather-app" -MapperPayload $audienceMapper

# react-app
$reactId = New-KeycloakClient -BaseUrl $KeycloakBaseUrl -Realm $RealmName `
    -AuthHeaders $authHeaders -ClientPayload $reactAppPayload

New-KeycloakProtocolMapper -BaseUrl $KeycloakBaseUrl -Realm $RealmName `
    -AuthHeaders $authHeaders -ClientInternalId $reactId `
    -ClientDisplayName "react-app" -MapperPayload $reactAudienceMapper

# user1
$user1Payload = @{
    username      = "user1"
    email         = "user1@example.com"
    emailVerified = $true
    enabled       = $true
    requiredActions = @()
    credentials   = @(
        @{
            type      = "password"
            value     = "password"
            temporary = $false
        }
    )
}
New-KeycloakUser -BaseUrl $KeycloakBaseUrl -Realm $RealmName `
    -AuthHeaders $authHeaders -UserPayload $user1Payload

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host ("{0,-17} {1}" -f "Realm:", $RealmName)
Write-Host ("{0,-17} {1}" -f "OIDC Discovery:", "$KeycloakBaseUrl/realms/$RealmName/.well-known/openid-configuration")
Write-Host ""
Write-Host ("{0,-15} {1}" -f "weather-app", "(confidential, Standard flow + Service Account Roles)") -ForegroundColor White
Write-Host ("{0,-15} {1}" -f "Client ID:", "weather-app")
Write-Host ("{0,-15} {1}" -f "Client Secret:", $weatherSecret)
Write-Host ""
Write-Host ("{0,-15} {1}" -f "react-app", "(public, Standard flow + Device Auth + PKCE S256)") -ForegroundColor White
Write-Host ("{0,-15} {1}" -f "Client ID:", "react-app")
Write-Host ("{0,-15} {1}" -f "Redirect URIs:", ($redirectUris -join ', '))
Write-Host ""
Write-Host ("{0,-15} {1}" -f "user1", "(pre-configured test user, no actions required on login)") -ForegroundColor White
Write-Host ("{0,-15} {1}" -f "Username:", "user1")
Write-Host ("{0,-15} {1}" -f "Password:", "password")
Write-Host ("{0,-15} {1}" -f "Email:", "user1@example.com")
Write-Host ""
Write-Host "Done!" -ForegroundColor Green
