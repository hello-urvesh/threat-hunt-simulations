[CmdletBinding()]
param(
    [string]$AtomicsFolder = 'C:\AtomicRedTeam\atomics',
    [string]$OutputDirectory = 'C:\AtomicRedTeam\amsi-evidence',
    [string[]]$TestGuids = @(
        '695eed40-e949-40e5-b306-b4031e4154bd',
        '6a8f4ee6-17d5-4a0e-b78d-7ec2cbf7c6ef',
        '087b9f84-2f44-4a50-a03e-bc50bd32d465',
        'e07cc0f9-cfad-4761-b83a-710a385a53fa',
        '667b2e29-a7cb-48d7-a315-a0b4e9a91d49'
    ),
    [switch]$SkipUpstreamInitFailed
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command Invoke-AtomicTest -ErrorAction SilentlyContinue)) {
    throw 'Invoke-AtomicTest was not found. Import Invoke-AtomicRedTeam first.'
}

$canaryScript = Join-Path $PSScriptRoot 'Invoke-AmsiCanary.ps1'
$collectorScript = Join-Path $PSScriptRoot 'Collect-AmsiTelemetry.ps1'
$atomicPath = Join-Path $AtomicsFolder 'T1685\T1685.yaml'

foreach ($path in @($canaryScript, $collectorScript, $atomicPath)) {
    if (-not (Test-Path $path)) { throw "Required file not found: $path" }
}

if ($SkipUpstreamInitFailed) {
    $TestGuids = @($TestGuids | Where-Object { $_ -ne '695eed40-e949-40e5-b306-b4031e4154bd' })
}

$runId = [Guid]::NewGuid().ToString('N')
$marker = "ART_AMSI_$runId"
$runDirectory = Join-Path $OutputDirectory $runId
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

$startTime = Get-Date
$results = [System.Collections.Generic.List[object]]::new()
$executedGuids = [System.Collections.Generic.List[string]]::new()

function Invoke-CleanCanary {
    param([Parameter(Mandatory)][string]$Phase)

    $outputPath = Join-Path $runDirectory ($Phase + '-canary.json')
    $escapedScript = $canaryScript.Replace("'", "''")
    $escapedMarker = ($marker + '_' + $Phase.ToUpperInvariant()).Replace("'", "''")
    $escapedOutput = $outputPath.Replace("'", "''")
    $command = "& '$escapedScript' -Marker '$escapedMarker' -OutputPath '$escapedOutput' | ConvertTo-Json -Depth 5"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $text = & powershell.exe -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | Out-String

    [pscustomobject]@{
        Phase = $Phase
        ExitCode = $LASTEXITCODE
        OutputPath = $outputPath
        ConsoleOutput = $text.Trim()
    }
}

try {
    $results.Add((Invoke-CleanCanary -Phase 'baseline'))

    foreach ($guid in $TestGuids) {
        $testMarker = "${marker}_$($guid.Substring(0, 8))"
        $started = Get-Date
        $status = 'completed'
        $errorMessage = $null

        try {
            Invoke-AtomicTest T1685 `
                -TestGuids $guid `
                -PathToAtomicsFolder $AtomicsFolder `
                -InputArgs @{
                    evidence_dir = $runDirectory
                    marker = $testMarker
                }
            $executedGuids.Add($guid)
        }
        catch {
            $status = 'failed_or_blocked'
            $errorMessage = $_.Exception.Message
        }

        $results.Add([pscustomobject]@{
            Phase = 'atomic'
            Guid = $guid
            Marker = $testMarker
            Started = $started
            Completed = Get-Date
            Status = $status
            Error = $errorMessage
        })
    }

    $results.Add((Invoke-CleanCanary -Phase 'post'))
}
finally {
    foreach ($guid in $executedGuids) {
        try {
            Invoke-AtomicTest T1685 `
                -TestGuids $guid `
                -PathToAtomicsFolder $AtomicsFolder `
                -InputArgs @{
                    evidence_dir = $runDirectory
                    marker = "${marker}_$($guid.Substring(0, 8))"
                } `
                -Cleanup
        }
        catch {
            $results.Add([pscustomobject]@{
                Phase = 'cleanup'
                Guid = $guid
                Status = 'cleanup_error'
                Error = $_.Exception.Message
            })
        }
    }

    try {
        & $collectorScript `
            -StartTime $startTime.AddMinutes(-1) `
            -EndTime (Get-Date).AddSeconds(30) `
            -Marker $marker `
            -OutputDirectory (Join-Path $runDirectory 'telemetry') | Out-Null
    }
    catch {
        $results.Add([pscustomobject]@{
            Phase = 'telemetry'
            Status = 'collection_error'
            Error = $_.Exception.Message
        })
    }

    [ordered]@{
        RunId = $runId
        Marker = $marker
        ComputerName = $env:COMPUTERNAME
        UserName = [Environment]::UserName
        Started = $startTime
        Completed = Get-Date
        AtomicsFolder = $AtomicsFolder
        TestGuids = $TestGuids
        Results = $results
    } | ConvertTo-Json -Depth 8 |
        Set-Content -Path (Join-Path $runDirectory 'run-summary.json') -Encoding UTF8
}

Write-Output "AMSI simulation completed. Evidence directory: $runDirectory"
