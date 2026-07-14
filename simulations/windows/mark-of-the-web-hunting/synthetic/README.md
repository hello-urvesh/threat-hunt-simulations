# Synthetic MOTW Events

`raw-sysmon/motw-events.jsonl` contains positive and negative Sysmon Event ID 15 examples.

`raw-sysmon/motw-correlation-events.jsonl` adds file creation, stream creation, ZoneId modification, container extraction, and execution sequences.

Use the datasets for Sigma conversion, parser development, unit testing, and workshops without endpoint access.

The samples do not prove that the Sysmon configuration or SIEM forwarder preserves the `Contents` field. Run the real endpoint simulation for collection validation.
