[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$events = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
$output = [System.Collections.Generic.List[object]]::new()

foreach ($event in @($events)) {
    $contents = if ($event.PSObject.Properties.Name -contains 'Contents') { [string]$event.Contents } else { '' }
    $target = if ($event.PSObject.Properties.Name -contains 'TargetFilename') { [string]$event.TargetFilename } else { '' }
    $zoneId = $null
    $hostUrl = $null
    $referrerUrl = $null
    $hostValue = $null
    $hostIsIp = $false
    $tld = $null

    if ($contents) {
        $zoneMatch = [regex]::Match($contents, '(?im)^ZoneId=(?<value>\d+)\s*$')
        $hostMatch = [regex]::Match($contents, '(?im)^HostUrl=(?<value>.+?)\s*$')
        $refMatch = [regex]::Match($contents, '(?im)^ReferrerUrl=(?<value>.+?)\s*$')
        if ($zoneMatch.Success) { $zoneId = [int]$zoneMatch.Groups['value'].Value }
        if ($hostMatch.Success) { $hostUrl = $hostMatch.Groups['value'].Value.Trim() }
        if ($refMatch.Success) { $referrerUrl = $refMatch.Groups['value'].Value.Trim() }
        if ($hostUrl) {
            try { $hostValue = ([uri]$hostUrl).Host } catch {
                if ($hostUrl -match '^(?:file:)?\\\\(?<host>[^\\]+)') { $hostValue = $Matches.host }
            }
        }
        if ($hostValue) {
            $ip = $null
            $hostIsIp = [System.Net.IPAddress]::TryParse($hostValue, [ref]$ip)
            if (-not $hostIsIp -and $hostValue.Contains('.')) { $tld = $hostValue.Split('.')[-1].ToLowerInvariant() }
        }
    }

    $normalized = [ordered]@{}
    foreach ($property in $event.PSObject.Properties) { $normalized[$property.Name] = $property.Value }
    $normalized['motw.zone_id'] = $zoneId
    $normalized['motw.host_url'] = $hostUrl
    $normalized['motw.referrer_url'] = $referrerUrl
    $normalized['motw.host'] = $hostValue
    $normalized['motw.host_is_ip'] = $hostIsIp
    $normalized['motw.tld'] = $tld
    $normalized['motw.stream_path'] = $target
    $output.Add([pscustomobject]$normalized)
}

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$output | ForEach-Object { $_ | ConvertTo-Json -Depth 6 -Compress } | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Normalized events written to $OutputPath"
