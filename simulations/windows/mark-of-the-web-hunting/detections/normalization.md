# MOTW Field Normalization

Cortex XDR exposes MOTW metadata as structured fields. Sysmon Event ID 15 places the same useful values inside the multiline `Contents` field.

## Source event

```text
[ZoneTransfer]
ZoneId=3
ReferrerUrl=https://portal.example.test/download
HostUrl=https://delivery-check.xyz/files/invoice.pdf.cmd
```

## Recommended fields

| Normalized field | Source |
|---|---|
| `motw.zone_id` | `ZoneId=` line |
| `motw.host_url` | `HostUrl=` line |
| `motw.referrer_url` | `ReferrerUrl=` line |
| `motw.host` | Host parsed from HostUrl |
| `motw.host_is_ip` | IP parser result |
| `motw.tld` | Last DNS label when host is not an IP |
| `file.path` | TargetFilename without `:Zone.Identifier` |
| `file.stream_path` | Full TargetFilename |

## Generic extraction expressions

```regex
(?im)^ZoneId=(?<motw_zone_id>\d+)\s*$
(?im)^HostUrl=(?<motw_host_url>.+?)\s*$
(?im)^ReferrerUrl=(?<motw_referrer_url>.+?)\s*$
```

## Quality checks

- Verify carriage returns and line feeds are preserved.
- Confirm URLs are not truncated at `&`, `?`, or `#` characters.
- Store ZoneId as an integer.
- Parse IPv4 and IPv6 with a real IP parser where possible.
- Keep both raw `Contents` and normalized fields.
- Correlate trusted zone values with prior ZoneId 3, process, user, and path context.
