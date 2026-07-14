# Expected Telemetry

## Event sequence

A successful real endpoint exercise should produce some or all of the following sequence:

1. Sysmon Event ID 11 when the lab file is created.
2. Sysmon Event ID 15 when `:Zone.Identifier` is written.
3. PowerShell Event ID 4104 for `Set-Content -Stream`, `Unblock-File`, or stream inspection.
4. A second Sysmon Event ID 15 when ZoneId is rewritten.
5. Sysmon Event ID 23 or 26 when supported deletion telemetry captures file or stream removal.
6. Sysmon Event ID 1 or Security Event ID 4688 when a safe marked command file is executed.
7. Additional EDR file, process, SmartScreen, or reputation events depending on the product.

## Sysmon Event ID 15 fields

| Field | Expected value |
|---|---|
| `Image` | Browser, PowerShell, Explorer, archive utility, or another creator |
| `TargetFilename` | Path ending in `:Zone.Identifier` |
| `Contents` | ZoneTransfer block with ZoneId and URL values |
| `ProcessGuid` | Correlation key for the process that wrote the stream |
| `Hash` | Hash of the unnamed file stream |

## Scenario expectations

| Scenario | Positive indicator |
|---|---|
| DirectIP | `HostUrl` has a public or documentation IP literal |
| SuspiciousTld | `HostUrl` host ends in a monitored TLD |
| FileSharing | URL includes a monitored sharing or CDN domain |
| DoubleExtension | Target path has a document extension followed by a script or executable extension |
| ExternalUNC | ReferrerUrl or HostUrl points to a remote UNC or file path |
| ZoneDowngrade | A stream is rewritten with ZoneId 0, 1, or 2 |
| MotwRemoval | `Unblock-File`, ADS deletion, or file deletion telemetry follows ZoneId 3 |
| ContainerInheritance | Container has MOTW and extracted child lacks it |
| Execution | Process command line references the earlier marked path |

## Expected gaps

- Windows process events alone do not expose HostUrl or ReferrerUrl.
- Some SIEM forwarders omit or truncate the multiline `Contents` field.
- Event ID 23 and 26 may not identify every ADS deletion on every Sysmon version and configuration.
- PowerShell logs require Script Block Logging for full command visibility.
- Browser behavior differs. The lab writes genuine ADS directly for deterministic coverage.
- Extracted file inheritance varies by archive format, extraction tool, and Windows build. Record the observed result.
