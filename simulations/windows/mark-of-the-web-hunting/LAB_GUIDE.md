# Mark of the Web Threat Hunting Lab Guide

## Lab outcome

At the end of the exercise, the learner should be able to generate real MOTW streams, validate Sysmon Event ID 15 collection, normalize MOTW fields, hunt suspicious origins and filenames, detect MOTW weakening, and correlate marked files with execution.

## Phase 1: Prepare the endpoint

1. Take a VM snapshot.
2. Confirm the working drive is NTFS.
3. Install or update Sysmon using the supplied lab configuration.
4. Enable PowerShell Script Block Logging when PowerShell detections are required.
5. Confirm the SIEM forwarder collects the Sysmon Operational channel.
6. Confirm time synchronization.

```powershell
Get-Volume -DriveLetter C | Select-Object DriveLetter, FileSystem, HealthStatus
Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents 5
```

## Phase 2: Validate the baseline

```powershell
.\scripts\New-MotwSimulationFile.ps1 `
  -Path C:\MOTW-Lab\baseline\sample.txt `
  -HostUrl https://download.example.test/sample.txt `
  -ReferrerUrl https://portal.example.test/download `
  -Scenario Baseline `
  -Force

Get-Item C:\MOTW-Lab\baseline\sample.txt -Stream *
Get-Content C:\MOTW-Lab\baseline\sample.txt -Stream Zone.Identifier
```

Confirm Event ID 15 locally and in the SIEM. Stop if `Contents` is missing or truncated.

## Phase 3: Generate scenarios

```powershell
.\scripts\Invoke-MotwSimulation.ps1 -Scenario All -RootPath C:\MOTW-Lab -ExecuteSafeMarkers
```

The printed `manifest.json` is the ground truth for paths and expected metadata.

## Phase 4: Collect evidence

```powershell
.\scripts\Collect-MotwTelemetry.ps1 `
  -StartTime (Get-Date).AddMinutes(-20) `
  -OutputDirectory C:\MOTW-Lab\telemetry
```

## Phase 5: Hunt in the SIEM

Run hunts in this order:

1. All Event ID 15 events.
2. Direct IP HostUrl.
3. Monitored TLD.
4. File sharing domain plus risky extension.
5. Double extension.
6. External UNC origin.
7. ZoneId 0, 1, or 2.
8. `Unblock-File` and `:Zone.Identifier` manipulation.
9. Marked file followed by execution.
10. Marked container followed by unmarked child and execution.

## Phase 6: Test Sigma

Convert the Sigma rules for the target backend. Confirm positive scenarios alert and negative samples do not. Tune approved file sharing domains, business TLDs, internal IP ranges, deployment tools, and analysis systems.

## Phase 7: Clean up

After SIEM ingestion completes:

```powershell
Remove-Item C:\MOTW-Lab -Recurse -Force
```

Restore the VM snapshot after the exercise.
