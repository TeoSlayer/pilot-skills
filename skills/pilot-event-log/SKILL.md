---
name: pilot-event-log
description: >
  Persistent NDJSON event logging with rotation, compression, and retention policies.

  Use this skill when:
  1. You need persistent storage of event streams
  2. You need log rotation and compression for long-term retention
  3. You need to audit event history with timestamps
  4. You need to export events for external analysis

  Do NOT use this skill when:
  - You need real-time event processing (use pilot-event-bus instead)
  - You need short-term replay (use pilot-event-replay instead)
  - You need filtered logs (use pilot-event-filter first, then log)
tags:
  - pilot-protocol
  - pub-sub
  - logging
  - audit
  - persistence
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
  Requires jq for JSON processing.
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - jq
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Pilot Event Log

Persistent NDJSON logging of Pilot Protocol event streams with rotation and compression.

## Commands

### Subscribe and Log
```bash
pilotctl --json subscribe <source> <topic> --timeout <seconds> | jq -c '.data.events[]' >> <log-file.ndjson>
```

### Query by Time
```bash
jq -c --arg start "2026-04-08T00:00:00Z" --arg end "2026-04-08T23:59:59Z" \
  'select(.timestamp >= $start and .timestamp <= $end)' events.ndjson
```

### Query by Topic
```bash
jq -c 'select(.topic | startswith("alerts."))' events.ndjson
```

### Rotate Logs
```bash
[ "$(du -m "$log_file" | cut -f1)" -ge "$MAX_SIZE_MB" ] && mv "$log_file" "$log_file.$(date +%s)" && gzip "$log_file.$(date +%s)" &
```

### Compress Old Logs
```bash
find /var/log/pilot-events -name "events-*.ndjson" -mtime +1 -exec gzip {} \;
```

### Retention Cleanup
```bash
find /var/log/pilot-events -name "events-*.ndjson.gz" -mtime +90 -delete
```

## Workflow Example

```bash
#!/bin/bash
# Production event logging

SOURCE="${1:-production-app}"
LOG_DIR="/var/log/pilot-events/$SOURCE"
MAX_SIZE_MB=500

mkdir -p "$LOG_DIR"
log_file="$LOG_DIR/current.ndjson"

while true; do
  pilotctl --json subscribe "$SOURCE" "*" --timeout 600 | jq -c '.data.events[]? // empty' | \
  while IFS= read -r event; do
    echo "$event" | jq -c '. + {logged_at: (now | todate)}' >> "$log_file"

    size_mb=$(du -m "$log_file" 2>/dev/null | cut -f1)
    if [ "${size_mb:-0}" -ge "$MAX_SIZE_MB" ]; then
      rotated="$LOG_DIR/events-$(date +%Y%m%d-%H%M%S).ndjson"
      mv "$log_file" "$rotated" && gzip "$rotated" &
    fi
  done
  sleep 5
done
```

## Dependencies

Requires pilot-protocol skill, jq (1.6+), gzip, and running daemon.
