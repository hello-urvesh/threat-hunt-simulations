# MOTW Correlation Guide

## Marked file followed by execution

Join Sysmon Event ID 15 to Sysmon Event ID 1 using the file path.

1. Remove `:Zone.Identifier` from `TargetFilename`.
2. Search process `CommandLine`, `Image`, or interpreter arguments for that path.
3. Use the same host and user when possible.
4. Start with a 30 minute window.
5. Raise confidence for risky extensions, direct IP origins, file sharing sources, and double extensions.

## Marked container followed by unmarked child

The core detection requires a ZIP, ISO, VHD, VHDX, IMG, or archive with ZoneId 3, a child created after extraction or mounting, and child execution without any prior Event ID 15 for the child path.

Useful process context includes Explorer, 7-Zip, WinRAR, tar, PowerShell `Expand-Archive`, and disk image mount activity. Absence-based logic should be implemented as a SIEM correlation or scheduled hunt.

## ZoneId downgrade

Correlate Event ID 15 records for the same file:

```text
Earlier Contents: ZoneId=3
Later Contents:   ZoneId=0, ZoneId=1, or ZoneId=2
```

## MOTW deletion

Possible signals include PowerShell `Unblock-File`, `Remove-Item -Stream Zone.Identifier`, EDR stream deletion telemetry, Sysmon Event ID 23 or 26 where supported, and execution after a prior Event ID 15 when the stream is no longer present.

## Correlation keys

1. Host plus canonical file path
2. Host plus file hash
3. ProcessGuid and descendants
4. User, host, path, and time window
5. Container path to child path based on archive process activity
