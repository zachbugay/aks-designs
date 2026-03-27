<#
.SYNOPSIS
    Generates a locations.yaml file by combining Azure CLI location data
    with region short names scraped from the Microsoft Learn geo-code list.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'locations.yaml')
)

# 1. Get location data from Azure CLI
Write-Host "Fetching locations from Azure CLI..."
$cliJson = az account list-locations --query "[].{regionalDisplayName: regionalDisplayName, name: name, displayName: displayName, pairedRegionName: metadata.pairedRegion[0].name}" -o json
if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure CLI command failed. Ensure you are logged in (az login)."
    return
}
$locations = $cliJson | ConvertFrom-Json

# 2. Fetch the geo-code HTML page
Write-Host "Fetching geo-code list from Microsoft Learn..."
$response = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/azure/backup/scripts/geo-code-list' -UseBasicParsing

# 3. Parse short names from the <code> block
#    The page contains HTML-encoded XML with GeoCode and RegionName attributes:
#    &lt;GeoCodeRegionNameMap GeoCode="EUS" RegionName="East US" /&gt;
$html = $response.Content
$shortNameMap = @{}

# Extract the code block content
$codeBlockMatch = [regex]::Match($html, '(?s)<code[^>]*>(.*?)</code>')
if ($codeBlockMatch.Success) {
    $codeContent = $codeBlockMatch.Groups[1].Value

    # Match GeoCode and RegionName attribute pairs from the HTML-encoded XML
    $entryMatches = [regex]::Matches($codeContent, 'GeoCode=(?:&quot;|")([^"&]+)(?:&quot;|")\s+RegionName=(?:&quot;|")([^"&]+)(?:&quot;|")')

    foreach ($entry in $entryMatches) {
        $geoCode = $entry.Groups[1].Value.Trim()
        $regionName = $entry.Groups[2].Value.Trim()
        if ($geoCode -and $regionName) {
            $shortNameMap[$regionName] = $geoCode
        }
    }
}

Write-Host "Found $($shortNameMap.Count) short name mappings from the webpage."

# 4. Build combined YAML output
$yamlLines = [System.Collections.Generic.List[string]]::new()
$yamlLines.Add('locations:')

foreach ($loc in $locations | Sort-Object -Property displayName) {
    $yamlLines.Add("  - DisplayName: $($loc.displayName)")
    $yamlLines.Add("    Name: $($loc.name)")

    $paired = if ($loc.pairedRegionName) { $loc.pairedRegionName } else { 'null' }
    $yamlLines.Add("    PairedRegion: $paired")

    $yamlLines.Add("    RegionalDisplayName: $($loc.regionalDisplayName)")

    # Add ShortName if we found a mapping
    if ($shortNameMap.ContainsKey($loc.displayName)) {
        $yamlLines.Add("    ShortName: $($shortNameMap[$loc.displayName])")
    }
}

$yamlContent = $yamlLines -join "`n"
$yamlContent | Set-Content -Path $OutputPath -Encoding utf8 -NoNewline
Write-Host "Wrote $($locations.Count) locations to $OutputPath"
