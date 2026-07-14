# MOTW Hunting Guide

## 1. Validate collection first

Create one baseline marked file and confirm the SIEM receives Sysmon Event ID 15, a `TargetFilename` ending in `:Zone.Identifier`, the complete `Contents` block, and host, user, image, and process correlation fields.

## 2. Hunt direct IP origins

Look for HostUrl values whose host is an IP literal. Exclude loopback, link local, RFC1918, approved proxies, and known internal download services. Prioritize script, shortcut, archive, disk image, and executable extensions, especially when followed by execution.

## 3. Hunt suspicious TLDs

Extract the HostUrl hostname and TLD. Use a monitored list that reflects the organization, threat intelligence, and business footprint. A rare TLD is context, not proof of maliciousness.

Increase confidence when the extension is executable or scriptable, the filename uses invoice or update language, the user has no history with the domain, or execution follows quickly.

## 4. Hunt file sharing services

Focus on risky extensions, newly observed senders or domains, unusual users, and rapid execution from public cloud storage, collaboration CDNs, temporary transfer services, paste sites, and code hosting.

## 5. Hunt double extensions

Search for a familiar document or image extension followed by an executable, script, shortcut, or command extension.

```text
invoice.pdf.cmd
resume.docx.js
photo.jpg.lnk
report.xlsx.scr
```

Correlate with Explorer, browser, email client, archive utility, or Office parent activity.

## 6. Hunt external UNC metadata

Search HostUrl and ReferrerUrl for UNC forms or `file://` URLs. Exclude approved shares and internal file servers. Prioritize raw IP shares and Internet zone files.

## 7. Hunt MOTW removal and weakening

Detection paths include PowerShell 4104 with `Unblock-File`, direct `:Zone.Identifier` manipulation, Event ID 15 showing ZoneId 3 followed by ZoneId 0, 1, or 2, EDR stream deletion events, and marked containers followed by unmarked children.

## 8. Correlate marked file execution

Use the normalized file path as the join key between Event ID 15 and process execution. Start with a 30 minute window. High value interpreters include `cmd.exe`, PowerShell, `wscript.exe`, `cscript.exe`, `mshta.exe`, `rundll32.exe`, and `regsvr32.exe`.

## 9. Negative testing

The synthetic dataset includes benign vendor downloads, intranet files, normal document extensions, and trusted zones. Rules should not alert on every marked file.

## 10. Investigation checklist

1. Retrieve raw Zone.Identifier contents.
2. Parse HostUrl, ReferrerUrl, ZoneId, and file path.
3. Check hash, signature, reputation, and prevalence.
4. Identify the creating process and parent.
5. Review network events around creation time.
6. Determine whether the file was renamed, moved, extracted, mounted, or unblocked.
7. Search for execution and child processes.
8. Review other downloads from the same origin and user.
9. Preserve the file and ADS for forensic examination.
