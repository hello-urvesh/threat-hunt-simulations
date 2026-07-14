[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'synthetic\raw-sysmon\generated-motw-events.jsonl'),
    [ValidateRange(1, 100)]
    [int]$CountPerScenario = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scenarios = @(
    @{ Name='DirectIP'; File='C:\Users\analyst\Downloads\security_update.js'; HostUrl='http://203.0.113.10/files/security_update.js'; ReferrerUrl='http://203.0.113.10/landing/index.html'; ZoneId=3; Image='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'; Label='positive' },
    @{ Name='SuspiciousTld'; File='C:\Users\analyst\Downloads\security_update.wsf'; HostUrl='https://delivery-check.xyz/files/security_update.wsf'; ReferrerUrl='https://delivery-check.xyz/landing'; ZoneId=3; Image='C:\Program Files\Google\Chrome\Application\chrome.exe'; Label='positive' },
    @{ Name='FileSharing'; File='C:\Users\analyst\Downloads\project_document.iso'; HostUrl='https://cdn.discordapp.com/attachments/lab/project_document.iso'; ReferrerUrl='https://discord.com/channels/lab'; ZoneId=3; Image='C:\Program Files\Microsoft\Edge\Application\msedge.exe'; Label='positive' },
    @{ Name='DoubleExtension'; File='C:\Users\analyst\Downloads\Quarterly_Report.pdf.cmd'; HostUrl='https://files.example.test/Quarterly_Report.pdf.cmd'; ReferrerUrl='https://files.example.test/share'; ZoneId=3; Image='C:\Program Files\Microsoft\Edge\Application\msedge.exe'; Label='positive' },
    @{ Name='ExternalUNC'; File='C:\Users\analyst\Downloads\invoice.zip'; HostUrl='file://203.0.113.25/documents/invoice.zip'; ReferrerUrl='\\203.0.113.25\documents\'; ZoneId=3; Image='C:\Windows\explorer.exe'; Label='positive' },
    @{ Name='ZoneDowngrade'; File='C:\Users\analyst\Downloads\invoice.docx.js'; HostUrl='https://delivery-check.xyz/files/invoice.docx.js'; ReferrerUrl='https://delivery-check.xyz/landing'; ZoneId=0; Image='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'; Label='positive' },
    @{ Name='BenignVendor'; File='C:\Users\analyst\Downloads\TeamsSetup.exe'; HostUrl='https://download.microsoft.com/TeamsSetup.exe'; ReferrerUrl='https://www.microsoft.com/'; ZoneId=3; Image='C:\Program Files\Microsoft\Edge\Application\msedge.exe'; Label='negative' },
    @{ Name='BenignDocument'; File='C:\Users\analyst\Downloads\policy.pdf'; HostUrl='https://intranet.example.com/policy.pdf'; ReferrerUrl='https://intranet.example.com/hr'; ZoneId=2; Image='C:\Program Files\Microsoft\Edge\Application\msedge.exe'; Label='negative' }
)

$events = [System.Collections.Generic.List[object]]::new()
$recordId = 10000
foreach ($scenario in $scenarios) {
    for ($i = 0; $i -lt $CountPerScenario; $i++) {
        $recordId++
        $timestamp = [DateTime]::UtcNow.AddSeconds($events.Count).ToString('o')
        $contents = @('[ZoneTransfer]',"ZoneId=$($scenario.ZoneId)","ReferrerUrl=$($scenario.ReferrerUrl)","HostUrl=$($scenario.HostUrl)") -join "`r`n"
        $events.Add([pscustomobject]@{
            TimeCreated = $timestamp
            Computer = 'MOTW-LAB-01'
            Provider = 'Microsoft-Windows-Sysmon'
            Channel = 'Microsoft-Windows-Sysmon/Operational'
            EventID = 15
            RecordID = $recordId
            RuleName = "MOTW-$($scenario.Name)"
            UtcTime = $timestamp
            ProcessGuid = '{11111111-2222-3333-4444-' + $recordId.ToString('000000000000') + '}'
            ProcessId = 4242
            Image = $scenario.Image
            TargetFilename = "$($scenario.File):Zone.Identifier"
            CreationUtcTime = $timestamp
            Hash = 'SHA256=' + ('A' * 64)
            Contents = $contents
            scenario = $scenario.Name
            expected_label = $scenario.Label
        })
    }
}

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$events | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Generated $($events.Count) synthetic events at $OutputPath"
