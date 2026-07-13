# Expected Telemetry

Coverage depends on Windows version, PowerShell edition, audit policy, Sysmon configuration, EDR product, and SIEM ingestion.

| Test | Expected evidence |
|---|---|
| Baseline canary | Clean child PowerShell process, 4104 canary content, baseline JSON |
| Upstream InitFailed | Reflection against `AmsiUtils`, Atomic PowerShell process, possible EDR prevention |
| Split identifier | String fragments, reflection, `split.json`, restored process state |
| Base64 boundary | `FromBase64String`, child `EncodedCommand`, boundary JSON |
| Memory protection surrogate | PInvoke script content, `amsi.dll` load, EDR VirtualProtect telemetry, zero bytes written |
| Registry tampering | Transient `AmsiEnable` write, restoration, registry state JSON |
| Post canary | Second clean PowerShell process, 4104 canary content, post JSON |

## Common gaps

| Gap | Possible explanation |
|---|---|
| No 4104 | Script Block Logging disabled, ingestion delayed, or script blocked |
| No 4103 | Module Logging disabled or no matching module activity |
| No 4688 | Process auditing disabled, command line auditing disabled, or access denied |
| No Sysmon events | Sysmon absent, log disabled, or configuration excludes the event |
| No memory event | EDR does not expose or detect VirtualProtect telemetry |
| No Defender event | The canary is harmless and may not trigger threat detection |
| Atomic blocked | A security control prevented the behavior, which is a valid result |
