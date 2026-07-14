[CmdletBinding()]
param(
    [ValidateSet('All','DirectIP','SuspiciousTld','FileSharing','DoubleExtension','ExternalUNC','ZoneDowngrade','MotwRemoval','ContainerInheritance','Execution')]
    [string[]]$Scenario = @('All'),

    [string]$RootPath = 'C:\MOTW-Lab',

    [switch]$ExecuteSafeMarkers
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This simulation requires Windows.'
}

$newMotwScript = Join-Path $PSScriptRoot 'New-MotwSimulationFile.ps1'
if (-not (Test-Path -LiteralPath $newMotwScript)) {
    throw "Missing helper script: $newMotwScript"
}

$runId = 'MOTW-{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0,8))
$runRoot = Join-Path $RootPath $runId
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$startTime = Get-Date
$results = [System.Collections.Generic.List[object]]::new()

$requested = if ($Scenario -contains 'All') {
    @('DirectIP','SuspiciousTld','FileSharing','DoubleExtension','ExternalUNC','ZoneDowngrade','MotwRemoval','ContainerInheritance','Execution')
} else {
    $Scenario
}

function Add-MotwArtifact {
    param(
        [string]$Name,
        [string]$RelativePath,
        [string]$HostUrl,
        [string]$ReferrerUrl,
        [int]$ZoneId = 3,
        [string]$Content = 'Harmless MOTW simulation marker.'
    )

    $path = Join-Path $runRoot $RelativePath
    $artifact = & $newMotwScript -Path $path -HostUrl $HostUrl -ReferrerUrl $ReferrerUrl -ZoneId $ZoneId -Content $Content -Scenario $Name -Force
    $results.Add($artifact)
    return $artifact
}

try {
    if ($requested -contains 'DirectIP') {
        Add-MotwArtifact -Name 'DirectIP' -RelativePath 'direct-ip\security_update.js' -HostUrl 'http://203.0.113.10/files/security_update.js' -ReferrerUrl 'http://203.0.113.10/landing/index.html' | Out-Null
    }

    if ($requested -contains 'SuspiciousTld') {
        Add-MotwArtifact -Name 'SuspiciousTld' -RelativePath 'suspicious-tld\security_update.wsf' -HostUrl 'https://delivery-check.xyz/files/security_update.wsf' -ReferrerUrl 'https://delivery-check.xyz/landing' | Out-Null
    }

    if ($requested -contains 'FileSharing') {
        Add-MotwArtifact -Name 'FileSharing' -RelativePath 'file-sharing\project_document.iso' -HostUrl 'https://cdn.discordapp.com/attachments/lab/project_document.iso' -ReferrerUrl 'https://discord.com/channels/lab' | Out-Null
    }

    if ($requested -contains 'DoubleExtension') {
        $markerPath = Join-Path $runRoot 'double-extension\execution-marker.txt'
        $command = '@echo MOTW_DOUBLE_EXTENSION_SAFE_MARKER>' + '"' + $markerPath + '"'
        Add-MotwArtifact -Name 'DoubleExtension' -RelativePath 'double-extension\Quarterly_Report.pdf.cmd' -HostUrl 'https://cdn.discordapp.com/attachments/lab/Quarterly_Report.pdf.cmd' -ReferrerUrl 'https://files.example.test/share' -Content $command | Out-Null
    }

    if ($requested -contains 'ExternalUNC') {
        Add-MotwArtifact -Name 'ExternalUNC' -RelativePath 'external-unc\invoice.zip' -HostUrl 'file://203.0.113.25/documents/invoice.zip' -ReferrerUrl '\\203.0.113.25\documents\' | Out-Null
    }

    if ($requested -contains 'ZoneDowngrade') {
        $artifact = Add-MotwArtifact -Name 'ZoneDowngradeBefore' -RelativePath 'zone-downgrade\invoice.docx.js' -HostUrl 'https://delivery-check.xyz/files/invoice.docx.js' -ReferrerUrl 'https://delivery-check.xyz/landing'
        $modified = $artifact.ZoneIdentifier -replace 'ZoneId=3','ZoneId=0'
        Set-Content -LiteralPath $artifact.Path -Stream Zone.Identifier -Value $modified -Encoding ASCII
        $results.Add([pscustomobject]@{
            TimestampUtc = [DateTime]::UtcNow.ToString('o')
            Scenario = 'ZoneDowngradeAfter'
            Path = $artifact.Path
            ZoneId = 0
            HostUrl = $artifact.HostUrl
            ReferrerUrl = $artifact.ReferrerUrl
            SHA256 = $artifact.SHA256
            ZoneIdentifier = (Get-Content -LiteralPath $artifact.Path -Stream Zone.Identifier -Raw)
        })
    }

    if ($requested -contains 'MotwRemoval') {
        $artifact = Add-MotwArtifact -Name 'MotwRemovalBefore' -RelativePath 'motw-removal\ReadMe.md' -HostUrl 'https://files.example.test/ReadMe.md' -ReferrerUrl 'https://files.example.test/download'
        Unblock-File -LiteralPath $artifact.Path
        $results.Add([pscustomobject]@{
            TimestampUtc = [DateTime]::UtcNow.ToString('o')
            Scenario = 'MotwRemovalAfter'
            Path = $artifact.Path
            ZoneId = $null
            HostUrl = $null
            ReferrerUrl = $null
            SHA256 = $artifact.SHA256
            ZoneIdentifier = $null
            StreamPresent = [bool](Get-Item -LiteralPath $artifact.Path -Stream Zone.Identifier -ErrorAction SilentlyContinue)
        })
    }

    if ($requested -contains 'ContainerInheritance') {
        $containerRoot = Join-Path $runRoot 'container'
        $sourceRoot = Join-Path $containerRoot 'source'
        $extractRoot = Join-Path $containerRoot 'extracted'
        $zipPath = Join-Path $containerRoot 'Quarterly_Reports.zip'
        New-Item -ItemType Directory -Path $sourceRoot,$extractRoot -Force | Out-Null
        $childSource = Join-Path $sourceRoot 'Quarterly_Report.pdf.cmd'
        $childMarker = Join-Path $containerRoot 'container-execution-marker.txt'
        Set-Content -LiteralPath $childSource -Value ('@echo MOTW_CONTAINER_SAFE_MARKER>"{0}"' -f $childMarker) -Encoding ASCII
        Compress-Archive -LiteralPath $childSource -DestinationPath $zipPath -Force
        $zone = @('[ZoneTransfer]','ZoneId=3','ReferrerUrl=https://files.example.test/share','HostUrl=https://cdn.example.test/Quarterly_Reports.zip') -join [Environment]::NewLine
        Set-Content -LiteralPath $zipPath -Stream Zone.Identifier -Value $zone -Encoding ASCII
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
        $childExtracted = Join-Path $extractRoot 'Quarterly_Report.pdf.cmd'
        $results.Add([pscustomobject]@{
            TimestampUtc = [DateTime]::UtcNow.ToString('o')
            Scenario = 'ContainerInheritance'
            ContainerPath = $zipPath
            ContainerMarked = [bool](Get-Item -LiteralPath $zipPath -Stream Zone.Identifier -ErrorAction SilentlyContinue)
            ExtractedChildPath = $childExtracted
            ExtractedChildMarked = [bool](Get-Item -LiteralPath $childExtracted -Stream Zone.Identifier -ErrorAction SilentlyContinue)
        })
        if ($ExecuteSafeMarkers) {
            & $env:ComSpec /d /c ('"{0}"' -f $childExtracted)
        }
    }

    if ($requested -contains 'Execution') {
        $executionMarker = Join-Path $runRoot 'execution\execution-marker.txt'
        $command = '@echo MOTW_EXECUTION_SAFE_MARKER>' + '"' + $executionMarker + '"'
        $artifact = Add-MotwArtifact -Name 'Execution' -RelativePath 'execution\Invoice_2026.pdf.cmd' -HostUrl 'https://delivery-check.xyz/Invoice_2026.pdf.cmd' -ReferrerUrl 'https://portal.example.test/invoices' -Content $command
        if ($ExecuteSafeMarkers) {
            & $env:ComSpec /d /c ('"{0}"' -f $artifact.Path)
            $results.Add([pscustomobject]@{
                TimestampUtc = [DateTime]::UtcNow.ToString('o')
                Scenario = 'ExecutionResult'
                Path = $artifact.Path
                MarkerPath = $executionMarker
                MarkerCreated = (Test-Path -LiteralPath $executionMarker)
            })
        }
    }
} finally {
    $manifest = [pscustomobject]@{
        RunId = $runId
        Hostname = $env:COMPUTERNAME
        User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Started = $startTime.ToUniversalTime().ToString('o')
        Completed = [DateTime]::UtcNow.ToString('o')
        RootPath = $runRoot
        RequestedScenarios = $requested
        ExecuteSafeMarkers = [bool]$ExecuteSafeMarkers
        Artifacts = $results
    }
    $manifestPath = Join-Path $runRoot 'manifest.json'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Host "MOTW simulation completed. Manifest: $manifestPath"
    Write-Host 'Artifacts were retained for SIEM ingestion and investigation. Remove the run directory after completing the exercise.'
}

$manifest
