[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [datetime]$StartTime,

    [datetime]$EndTime = (Get-Date).AddMinutes(2),

    [Parameter(Mandatory)]
    [string]$Marker,

    [Parameter(Mandatory)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$requests = @(
    @{ Name = 'powershell-operational'; LogName = 'Microsoft-Windows-PowerShell/Operational'; Ids = @(4103, 4104) },
    @{ Name = 'windows-defender-operational'; LogName = 'Microsoft-Windows-Windows Defender/Operational'; Ids = @(1116, 1117, 5007) },
    @{ Name = 'security-process-creation'; LogName = 'Security'; Ids = @(4688) },
    @{ Name = 'sysmon-operational'; LogName = 'Microsoft-Windows-Sysmon/Operational'; Ids = @(1, 7, 10, 12, 13) }
)

$summary = [System.Collections.Generic.List[object]]::new()

foreach ($request in $requests) {
    $status = 'collected'
    $errorMessage = $null
    $events = @()

    try {
        $log = Get-WinEvent -ListLog $request.LogName -ErrorAction Stop
        if (-not $log.IsEnabled) {
            $status = 'log_disabled'
        }
        else {
            $events = @(Get-WinEvent -FilterHashtable @{
                LogName = $request.LogName
                Id = $request.Ids
                StartTime = $StartTime
                EndTime = $EndTime
            } -ErrorAction Stop)
        }
    }
    catch {
        $status = 'unavailable'
        $errorMessage = $_.Exception.Message
    }

    $normalized = foreach ($event in $events) {
        [ordered]@{
            TimeCreated = $event.TimeCreated
            Id = $event.Id
            RecordId = $event.RecordId
            ProviderName = $event.ProviderName
            MachineName = $event.MachineName
            MarkerMatched = ($event.Message -like "*$Marker*")
            AmsiMatched = ($event.Message -match '(?i)amsi|AmsiUtils|amsiInitFailed|AmsiEnable|AmsiScanBuffer')
            Message = $event.Message
        }
    }

    @($normalized) | ConvertTo-Json -Depth 6 |
        Set-Content -Path (Join-Path $OutputDirectory ($request.Name + '.json')) -Encoding UTF8
    @($normalized) | Export-Csv -Path (Join-Path $OutputDirectory ($request.Name + '.csv')) -NoTypeInformation -Encoding UTF8

    $summary.Add([pscustomobject]@{
        Name = $request.Name
        LogName = $request.LogName
        Status = $status
        EventCount = @($events).Count
        MarkerMatches = @($normalized | Where-Object MarkerMatched).Count
        AmsiMatches = @($normalized | Where-Object AmsiMatched).Count
        Error = $errorMessage
    })
}

$summary | ConvertTo-Json -Depth 4 |
    Set-Content -Path (Join-Path $OutputDirectory 'collection-summary.json') -Encoding UTF8
$summary
