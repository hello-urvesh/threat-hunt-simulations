# AMSI Simulation Hunting Guide

## What this pack generates

- PowerShell reflection against internal `System.Management.Automation` types
- Access to `AmsiUtils` and `amsiInitFailed`
- Runtime string construction and Base64 decoding
- Parent PowerShell to child PowerShell process creation
- `amsi.dll` loading and `AmsiScanBuffer` resolution
- Page protection changes around `AmsiScanBuffer`
- Registry writes to `AmsiEnable`
- Unique exercise markers in logs and JSON evidence

## Primary data sources

| Data source | Useful evidence |
|---|---|
| PowerShell Operational | Event ID 4103 and 4104 |
| Security | Event ID 4688 when command line auditing is enabled |
| Sysmon | Event ID 1, 7, 10, 12, and 13 depending on configuration |
| Microsoft Defender | Event ID 1116, 1117, and 5007 when relevant |
| EDR | Script content, reflection, memory protection changes, module loads, and process lineage |
| Registry telemetry | Writes to `AmsiEnable` and related script engine settings |

## Hunt 1: PowerShell AMSI reflection

Search PowerShell or Pwsh command lines and script content for:

```text
System.Management.Automation.AmsiUtils
amsiInitFailed
GetField
NonPublic,Static
SetValue
```

High confidence combinations:

- `AmsiUtils` with `GetField`
- `amsiInitFailed` with `SetValue`
- `System.Management.Automation` with `NonPublic,Static`
- Base64 decoding followed by reflection

Likely legitimate sources are security research, red team tooling, and endpoint validation.

## Hunt 2: Base64 reconstruction and child PowerShell

Correlate:

1. PowerShell uses `FromBase64String`.
2. Decoded values are used with reflection.
3. The process launches `powershell.exe` with `EncodedCommand`.
4. The child inspects the same internal field.

Do not alert only on `EncodedCommand`. Require AMSI context or suspicious reflection.

## Hunt 3: AMSI memory protection changes

Useful EDR conditions:

- Process is PowerShell or Pwsh
- Module is `amsi.dll`
- Target address maps to `AmsiScanBuffer`
- Protection changes to writable and executable
- The action occurs shortly after `amsi.dll` loads

The custom test writes no bytes. A real attack may follow the protection change with a memory write.

## Hunt 4: Registry tampering

Monitor:

```text
HKCU\Software\Microsoft\Windows Script\Settings\AmsiEnable
```

Alert on value creation, a value of zero, rapid create and delete patterns, or PowerShell modifying the value.

## Correlation workflow

1. Search for the marker from `run-summary.json`.
2. Identify baseline and post canary processes.
3. Locate each Atomic process and evidence file.
4. Review Event ID 4104 for AMSI content.
5. Review process lineage, registry events, and module loads.
6. Review EDR memory telemetry.
7. Compare results with `expected-telemetry.md`.
8. Record missing data as a collection or ingestion gap.

Do not build production detections around the exercise GUIDs or markers. Use the underlying behavior.
