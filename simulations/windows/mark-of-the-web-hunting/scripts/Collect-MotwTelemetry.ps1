[CmdletBinding()]
param(
    [datetime]$StartTime = (Get-Date).AddMinutes(-30),
    [datetime]$EndTime = (Get-Date).AddMinutes(2),
    [string]$OutputDirectory = 'C:\MOTW-Lab\telemetry',
    [string]$PathContains = '\MOTW-Lab\'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Convert-EventRecord {
    param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
    $xml = [xml]$Event.ToXml()
    $data = [ordered]@{
        TimeCreated = $Event.TimeCreated.ToUniversalTime().ToString('o')
        Computer = $Event.MachineName
        Provider = $Event.ProviderName
        Channel = $Event.LogName
        EventID = $Event.Id
        RecordID = $Event.RecordId
    }
    foreach ($node in $xml.Event.EventData.Data) {
        $name = [string]$node.Name
        if (-not $name) { $name = "Data$($data.Count)" }
        $data[$name] = [string]$node.'#text'
    }
    [pscustomobject]$data
}

function Get-EventsSafe {
    param([string]$LogName,[int[]]$Ids)
    try {
        Get-WinEvent -FilterHashtable @{LogName=$LogName;Id=$Ids;StartTime=$StartTime;EndTime=$EndTime} -ErrorAction Stop | ForEach-Object { Convert-EventRecord -Event $_ }
    } catch {
        Write-Warning "Unable to read $LogName: $($_.Exception.Message)"
        @()
    }
}

$sysmon = @(Get-EventsSafe -LogName 'Microsoft-Windows-Sysmon/Operational' -Ids @(1,11,15,23,26))
$powershell = @(Get-EventsSafe -LogName 'Microsoft-Windows-PowerShell/Operational' -Ids @(4103,4104))
$security = @(Get-EventsSafe -LogName 'Security' -Ids @(4688))

if ($PathContains) {
    $sysmon = @($sysmon | Where-Object {
        ($_.PSObject.Properties.Name -contains 'TargetFilename' -and $_.TargetFilename -like "*$PathContains*") -or
        ($_.PSObject.Properties.Name -contains 'CommandLine' -and $_.CommandLine -like "*$PathContains*") -or
        ($_.PSObject.Properties.Name -contains 'ParentCommandLine' -and $_.ParentCommandLine -like "*$PathContains*")
    })
    $powershell = @($powershell | Where-Object {
        ($_.PSObject.Properties.Name -contains 'ScriptBlockText' -and $_.ScriptBlockText -like "*$PathContains*") -or
        ($_.PSObject.Properties.Name -contains 'Path' -and $_.Path -like "*$PathContains*") -or
        ($_.PSObject.Properties.Name -contains 'Payload' -and $_.Payload -like "*$PathContains*")
    })
    $security = @($security | Where-Object {
        ($_.PSObject.Properties.Name -contains 'CommandLine' -and $_.CommandLine -like "*$PathContains*") -or
        ($_.PSObject.Properties.Name -contains 'NewProcessName' -and $_.NewProcessName -like "*$PathContains*") -or
        ($_.PSObject.Properties.Name -contains 'ParentProcessName' -and $_.ParentProcessName -like "*$PathContains*")
    })
}

$rawPath = Join-Path $OutputDirectory 'motw-events-raw.json'
@($sysmon + $powershell + $security) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $rawPath -Encoding UTF8
$sysmon | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'sysmon-events.csv') -NoTypeInformation -Encoding UTF8
$powershell | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'powershell-events.csv') -NoTypeInformation -Encoding UTF8
$security | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'security-events.csv') -NoTypeInformation -Encoding UTF8

$converter = Join-Path $PSScriptRoot 'Convert-MotwEvents.ps1'
if (Test-Path -LiteralPath $converter) {
    & $converter -InputPath $rawPath -OutputPath (Join-Path $OutputDirectory 'motw-events-normalized.jsonl')
}

[pscustomobject]@{
    OutputDirectory = $OutputDirectory
    SysmonEvents = $sysmon.Count
    PowerShellEvents = $powershell.Count
    SecurityEvents = $security.Count
    RawJson = $rawPath
}
