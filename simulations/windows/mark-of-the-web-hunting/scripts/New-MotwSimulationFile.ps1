[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$HostUrl,

    [string]$ReferrerUrl = '',

    [ValidateRange(0, 4)]
    [int]$ZoneId = 3,

    [string]$Content = 'Harmless Mark of the Web simulation marker.',

    [string]$Scenario = 'Custom',

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This script requires Windows and an NTFS volume.'
}

$expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
$parent = Split-Path -Parent $expandedPath
if (-not $parent) {
    throw "The path must include a parent directory: $expandedPath"
}

New-Item -ItemType Directory -Path $parent -Force | Out-Null

if ((Test-Path -LiteralPath $expandedPath) -and -not $Force) {
    throw "The file already exists. Use -Force to replace it: $expandedPath"
}

Set-Content -LiteralPath $expandedPath -Value $Content -Encoding UTF8 -Force

$zoneLines = [System.Collections.Generic.List[string]]::new()
$zoneLines.Add('[ZoneTransfer]')
$zoneLines.Add("ZoneId=$ZoneId")
if ($ReferrerUrl) { $zoneLines.Add("ReferrerUrl=$ReferrerUrl") }
$zoneLines.Add("HostUrl=$HostUrl")
$zoneContent = $zoneLines -join [Environment]::NewLine

try {
    Set-Content -LiteralPath $expandedPath -Stream Zone.Identifier -Value $zoneContent -Encoding ASCII
} catch {
    Remove-Item -LiteralPath $expandedPath -Force -ErrorAction SilentlyContinue
    throw "Unable to create Zone.Identifier. Confirm the path is on NTFS. $($_.Exception.Message)"
}

$streamContent = Get-Content -LiteralPath $expandedPath -Stream Zone.Identifier -Raw
$hash = Get-FileHash -LiteralPath $expandedPath -Algorithm SHA256

[pscustomobject]@{
    TimestampUtc = [DateTime]::UtcNow.ToString('o')
    Scenario = $Scenario
    Path = $expandedPath
    ZoneId = $ZoneId
    HostUrl = $HostUrl
    ReferrerUrl = $ReferrerUrl
    SHA256 = $hash.Hash
    ZoneIdentifier = $streamContent
}
