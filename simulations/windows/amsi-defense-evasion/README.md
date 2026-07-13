# AMSI Defense Evasion Simulation Pack

This module provides Atomic Red Team compatible simulations for generating telemetry related to PowerShell AMSI bypass and tampering techniques.

Use it on isolated Windows lab systems where endpoint telemetry is forwarded to a SIEM for threat hunting and detection engineering practice.

## Goals

- Generate PowerShell, process, registry, and EDR telemetry associated with AMSI evasion
- Compare baseline and post simulation behavior
- Practice writing and validating detections
- Preserve evidence from every exercise run
- Avoid downloading or executing malware

## Included tests

| Test | Source | Behavior | Persistent change |
|---|---|---|---|
| AMSI InitFailed | Upstream Atomic Red Team | Sets the PowerShell internal `amsiInitFailed` field | No, process local |
| Split identifier InitFailed | Custom | Constructs AMSI identifiers at runtime, records evidence, and restores state | No |
| Base64 identifier boundary test | Custom | Reconstructs identifiers from Base64 and compares current and child process state | No |
| AMSI memory protection telemetry surrogate | Custom | Changes page protection around `AmsiScanBuffer`, writes no bytes, and restores protection | No |
| AMSIEnable registry tampering | Custom | Sets `AmsiEnable` to zero and restores the exact previous state | No |

## Safety model

- Run only in an isolated Windows virtual machine.
- Take a snapshot before testing.
- The pack uses harmless canary commands.
- The memory test does not patch `amsi.dll`.
- The registry test restores the exact previous value and type.
- The upstream InitFailed test is process local and ends when its PowerShell process exits.
- EDR prevention or script blocking is a valid exercise result.

## Requirements

- Windows 10, Windows 11, or a supported Windows Server lab VM
- Windows PowerShell 5.1 for the closest match to common AMSI bypass behavior
- Atomic Red Team and Invoke-AtomicRedTeam
- PowerShell Script Block Logging for Event ID 4104
- PowerShell Module Logging for Event ID 4103
- Process creation auditing or Sysmon
- An EDR sensor for memory protection telemetry

PowerShell 7 can be tested separately, but behavior and event coverage may differ.

## Install the Atomic

```powershell
$Source = ".\simulations\windows\amsi-defense-evasion\atomics\T1685"
$Destination = "C:\AtomicRedTeam\atomics\T1685"
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
Copy-Item "$Source\T1685.yaml" "$Destination\T1685.yaml" -Force
```

Show details and check prerequisites:

```powershell
Invoke-AtomicTest T1685 -ShowDetails
Invoke-AtomicTest T1685 -CheckPrereqs
```

## Recommended guided run

Run from an elevated Windows PowerShell console:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Run-AmsiSimulation.ps1 `
  -AtomicsFolder "C:\AtomicRedTeam\atomics" `
  -OutputDirectory "C:\AtomicRedTeam\amsi-evidence"
```

The runner:

1. Creates a unique exercise marker.
2. Runs a baseline canary in a clean child process.
3. Runs each selected Atomic by GUID.
4. Runs a post simulation canary in another clean child process.
5. Collects relevant event logs.
6. Writes a run summary.
7. Calls Atomic cleanup in a `finally` block.

## Run one test manually

```powershell
Invoke-AtomicTest T1685 `
  -TestGuids 6a8f4ee6-17d5-4a0e-b78d-7ec2cbf7c6ef `
  -InputArgs @{
    evidence_dir = "C:\AtomicRedTeam\amsi-evidence"
    marker = "ART_AMSI_MANUAL_TEST"
  }
```

Cleanup:

```powershell
Invoke-AtomicTest T1685 `
  -TestGuids 6a8f4ee6-17d5-4a0e-b78d-7ec2cbf7c6ef `
  -Cleanup
```

## Validate the pack

```powershell
.\scripts\Test-AmsiPack.ps1
```

## Evidence

Evidence is written under the selected output directory and includes:

- Baseline canary JSON
- Per test JSON evidence
- Post simulation canary JSON
- PowerShell Operational events
- Defender Operational events
- Security process creation events when accessible
- Sysmon events when installed
- Run summary with timestamps, marker, host, user, and selected GUIDs

## Interpretation

A command completing successfully does not prove that AMSI was bypassed.

- InitFailed tests prove that a process local PowerShell internal field was changed.
- The boundary test shows whether state crossed into a clean child process.
- The memory test proves that page protection was changed and restored, not that AMSI was patched.
- SIEM and EDR telemetry determine whether monitoring detected the behavior.
- Missing telemetry can indicate a collection gap, ingestion delay, product limitation, or evasion.

## Attribution

The original AMSI InitFailed Atomic is copied from Atomic Red Team and retains its original GUID. See `THIRD_PARTY_NOTICES.md`.
