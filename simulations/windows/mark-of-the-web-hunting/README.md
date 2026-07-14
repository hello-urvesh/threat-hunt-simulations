# Mark of the Web Hunting Simulation

A Windows threat hunting lab for generating and detecting Mark of the Web telemetry in a SIEM.

The pack creates genuine NTFS `Zone.Identifier` alternate data streams, safe process activity, and container extraction scenarios. It also includes Atomic Red Team compatible YAML, Sysmon collection guidance, Sigma rules, SIEM queries, and synthetic sample events.

## Learning goals

- Understand how Windows stores Mark of the Web metadata.
- Collect Sysmon Event ID 15 and preserve the `Contents` field.
- Parse `ZoneId`, `HostUrl`, and `ReferrerUrl` into SIEM fields.
- Hunt direct IP origins, suspicious top level domains, file sharing services, double extensions, and UNC origins.
- Detect removal or weakening of the `Zone.Identifier` stream.
- Correlate marked files with later execution.
- Compare a marked archive with an extracted child that does not inherit MOTW.

## Safety

The pack does not download or execute malware. Payload files are harmless text and command markers. Reserved documentation IP addresses and controlled URLs are used inside MOTW metadata. Run the pack in an isolated Windows lab VM.

## Recommended telemetry

| Source | Events | Purpose |
|---|---|---|
| Sysmon | 15 | Named stream creation and MOTW contents |
| Sysmon | 11 | File creation |
| Sysmon | 1 | Process execution |
| Sysmon | 23 or 26 | File and stream deletion visibility where available |
| PowerShell Operational | 4104 | `Unblock-File` and ADS manipulation |
| Security | 4688 | Process creation fallback |
| EDR | File and process events | Product specific correlation and prevention |

Sysmon Event ID 15 is the most important source. The SIEM forwarder must retain the multiline `Contents` field.

## Prerequisites

- Windows 10, Windows 11, Windows Server 2016, or newer.
- An NTFS volume.
- Windows PowerShell 5.1 or PowerShell 7.
- Sysmon configured to collect Event ID 15.
- Invoke-AtomicRedTeam when running the YAML tests.

## Quick start without Atomic Red Team

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Test-MotwPack.ps1
.\scripts\Invoke-MotwSimulation.ps1 -Scenario All -RootPath C:\MOTW-Lab -ExecuteSafeMarkers
```

Collect endpoint events:

```powershell
.\scripts\Collect-MotwTelemetry.ps1 -StartTime (Get-Date).AddMinutes(-20) -OutputDirectory C:\MOTW-Lab\telemetry
```

## Atomic Red Team usage

Use a custom atomics path or merge the `atomic_tests` arrays into an existing Atomic Red Team installation. Do not overwrite upstream technique YAML without reviewing and merging its existing tests.

```powershell
Invoke-AtomicTest T1553.005 -ShowDetails
Invoke-AtomicTest T1553.005 -CheckPrereqs
Invoke-AtomicTest T1553.005
Invoke-AtomicTest T1553.005 -Cleanup
Invoke-AtomicTest T1036.007
Invoke-AtomicTest T1204.002
```

The T1553.005 YAML includes the upstream Atomic Red Team `Unblock-File` test with its original GUID and attribution.

## Scenarios

| Scenario | Example | Expected hunt |
|---|---|---|
| Direct public IP | `http://203.0.113.10/files/update.js` | Internet origin represented by an IP address |
| Suspicious TLD | `https://delivery-check.xyz/security_update.wsf` | Rare or risky top level domain |
| File sharing service | Discord CDN style URL | Risky extension delivered by a file sharing service |
| Double extension | `Quarterly_Report.pdf.cmd` | Masquerading with a second executable extension |
| External UNC origin | `\\203.0.113.25\documents\invoice.zip` | MOTW points to a remote share |
| MOTW removal | `Unblock-File` | Zone.Identifier is deleted |
| Zone downgrade | `ZoneId=3` changed to `ZoneId=0` | Internet zone changed to a trusted local zone |
| Container inheritance | Marked ZIP and unmarked extracted child | Child escapes inherited MOTW controls |
| Marked file execution | Safe command marker | Correlate MOTW creation with execution |

The IP ranges `192.0.2.0/24`, `198.51.100.0/24`, and `203.0.113.0/24` are used only as documentation metadata.

## Sysmon setup

The supplied `sysmon/sysmon-motw-lab.xml` is a focused lab configuration. Merge its relevant rules into production configurations instead of replacing them blindly.

```powershell
Sysmon64.exe -accepteula -i .\sysmon\sysmon-motw-lab.xml
Sysmon64.exe -c .\sysmon\sysmon-motw-lab.xml
```

## SIEM normalization

Recommended fields:

```text
motw.zone_id
motw.host_url
motw.referrer_url
motw.host
motw.host_is_ip
motw.tld
file.path
process.executable
process.command_line
host.name
user.name
```

## Synthetic dataset

The `synthetic/raw-sysmon` folder contains positive, negative, and correlation samples for rule testing when a Windows VM is unavailable.

## Validation

```powershell
.\scripts\Test-MotwPack.ps1
```

## References

- Palo Alto Networks, Threat Hunting with Mark of the Web Using Cortex XDR
- Microsoft Sysmon Event ID 15 documentation
- MITRE ATT&CK T1553.005
- Atomic Red Team T1553.005
- SigmaHQ MOTW and Zone.Identifier rules
