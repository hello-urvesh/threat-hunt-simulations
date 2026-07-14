[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$required = @(
    'README.md','LAB_GUIDE.md','THIRD_PARTY_NOTICES.md',
    'atomics\T1553.005\T1553.005.yaml','atomics\T1036.007\T1036.007.yaml','atomics\T1204.002\T1204.002.yaml',
    'scripts\New-MotwSimulationFile.ps1','scripts\Invoke-MotwSimulation.ps1','scripts\Collect-MotwTelemetry.ps1',
    'scripts\Convert-MotwEvents.ps1','scripts\Generate-MotwSyntheticLogs.ps1','sysmon\sysmon-motw-lab.xml'
)
$failures = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) { $failures.Add("Missing required file: $relative") }
}

$yamlFiles = Get-ChildItem -LiteralPath (Join-Path $root 'atomics') -Filter '*.yaml' -Recurse
$guids = [System.Collections.Generic.List[string]]::new()
foreach ($yaml in $yamlFiles) {
    $text = Get-Content -LiteralPath $yaml.FullName -Raw
    if ($text -notmatch '(?m)^attack_technique:\s*T\d{4}(?:\.\d{3})?\s*$') { $failures.Add("Missing or invalid attack_technique in $($yaml.FullName)") }
    if ($text -notmatch '(?m)^atomic_tests:\s*$') { $failures.Add("Missing atomic_tests in $($yaml.FullName)") }
    foreach ($match in [regex]::Matches($text, '(?m)^\s*auto_generated_guid:\s*(?<guid>[0-9a-fA-F-]{36})\s*$')) {
        $guid = $match.Groups['guid'].Value
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse($guid, [ref]$parsed)) { $failures.Add("Invalid GUID $guid in $($yaml.FullName)") }
        $guids.Add($guid.ToLowerInvariant())
    }
}
foreach ($duplicate in ($guids | Group-Object | Where-Object Count -gt 1)) { $failures.Add("Duplicate Atomic GUID: $($duplicate.Name)") }

$sigmaFiles = Get-ChildItem -LiteralPath (Join-Path $root 'detections\sigma') -Filter '*.yml' -Recurse
foreach ($sigma in $sigmaFiles) {
    $text = Get-Content -LiteralPath $sigma.FullName -Raw
    foreach ($field in @('title:','id:','logsource:','detection:','condition:')) {
        if ($text -notmatch "(?m)^\s*$([regex]::Escape($field))") { $failures.Add("Sigma field $field missing in $($sigma.FullName)") }
    }
}

try { [xml](Get-Content -LiteralPath (Join-Path $root 'sysmon\sysmon-motw-lab.xml') -Raw) | Out-Null } catch { $failures.Add("Sysmon XML is invalid: $($_.Exception.Message)") }
Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
    if ($text -match '[\u2013\u2014]') { $failures.Add("Long dash character found in $($_.FullName)") }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "MOTW pack validation failed with $($failures.Count) issue(s)."
}
[pscustomobject]@{Status='Passed';AtomicYamlFiles=$yamlFiles.Count;AtomicGuids=$guids.Count;SigmaRules=$sigmaFiles.Count;RequiredFiles=$required.Count}
