[CmdletBinding()]
param(
    [string]$Marker = "ART_AMSI_CANARY_$([Guid]::NewGuid().ToString('N'))",
    [string]$OutputPath = "$env:TEMP\amsi-canary-$PID.json"
)

$ErrorActionPreference = 'Stop'

function Get-AmsiInitFailedState {
    try {
        $type = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        if ($null -eq $type) { return $null }
        $field = $type.GetField('amsiInitFailed', 'NonPublic,Static')
        if ($null -eq $field) { return $null }
        return [bool]$field.GetValue($null)
    }
    catch {
        return $null
    }
}

$started = [DateTime]::UtcNow
$before = Get-AmsiInitFailedState
$command = 'Write-Output "' + $Marker.Replace('"', '""') + '"'
$output = Invoke-Expression $command | Out-String
$after = Get-AmsiInitFailedState

$parentProcessId = $null
try {
    $parentProcessId = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId
}
catch {
    $parentProcessId = $null
}

$result = [ordered]@{
    Marker = $Marker
    TimestampUtc = $started.ToString('o')
    CompletedUtc = [DateTime]::UtcNow.ToString('o')
    ComputerName = $env:COMPUTERNAME
    UserName = [Environment]::UserName
    ProcessId = $PID
    ParentProcessId = $parentProcessId
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    PowerShellEdition = $PSVersionTable.PSEdition
    AmsiInitFailedBefore = $before
    AmsiInitFailedAfter = $after
    CanaryOutput = $output.Trim()
    Success = ($output -match [Regex]::Escape($Marker))
}

$directory = Split-Path -Parent $OutputPath
if ($directory) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$result | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
$result
