# AMSI Simulation Hunting Guide

## Telemetry sources

- PowerShell Operational logs
- Script Block Logging Event ID 4104
- Module Logging Event ID 4103
- Process creation Event ID 4688
- Sysmon process and image load events
- EDR memory and script telemetry

## Hunting ideas

Look for:

- PowerShell reflection against System.Management.Automation.AmsiUtils
- Access to amsiInitFailed
- PowerShell loading unusual assemblies
- Memory protection changes involving amsi.dll
- Suspicious PowerShell child process relationships
- Defender configuration changes

## Exercise methodology

1. Capture baseline telemetry.
2. Run the Atomic simulation.
3. Compare expected and observed logs.
4. Create detections from observed behavior.
