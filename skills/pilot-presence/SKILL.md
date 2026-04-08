---
name: pilot-presence
description: >
  Real-time online/offline/busy presence tracking for agent fleets using ping and pub/sub.

  Use this skill when:
  1. You need to track which agents are online/offline/busy
  2. You need to broadcast presence changes to interested peers
  3. You need to discover available agents for task routing
  4. You need to maintain a real-time agent directory

  Do NOT use this skill when:
  - You only need static peer discovery (use pilotctl trust instead)
  - You need detailed health metrics (use pilot-metrics instead)
  - You need persistent audit logs (use pilot-event-log instead)
tags:
  - pilot-protocol
  - pub-sub
  - presence
  - discovery
  - health
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

# Pilot Presence

Real-time presence tracking for Pilot Protocol agents. Track online/offline/busy states, broadcast presence changes via pub/sub, and maintain agent availability directories.

## Commands

**Ping for liveness:**
```bash
pilotctl --json ping <target-hostname> [--count <n>] [--timeout <ms>]
```

**Get connected peers:**
```bash
pilotctl --json peers
```

**Publish presence:**
```bash
pilotctl --json publish <target-hostname> "presence.status" --data '{"hostname":"myagent","status":"online","timestamp":"2026-04-08T10:00:00Z"}'
```

**Subscribe to presence:**
```bash
pilotctl --json subscribe <target-hostname> "presence.*" [--timeout <seconds>]
```

## Workflow Example

```bash
#!/bin/bash
# Broadcast presence every 30 seconds

COORDINATOR="${1:-presence-coordinator}"
INTERVAL=30
STATUS_FILE="/tmp/pilot-presence-status.txt"
echo "online" > "$STATUS_FILE"

while true; do
  status=$(cat "$STATUS_FILE" 2>/dev/null || echo "online")
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  info=$(pilotctl --json info 2>/dev/null)
  hostname=$(echo "$info" | jq -r '.data.hostname // "unknown"')

  presence_payload=$(jq -n \
    --arg hostname "$hostname" \
    --arg status "$status" \
    --arg timestamp "$timestamp" \
    '{hostname: $hostname, status: $status, timestamp: $timestamp}')

  pilotctl --json publish "$COORDINATOR" "presence.status" --data "$presence_payload"
  sleep "$INTERVAL"
done
```

## Presence States

- **online**: Agent is reachable and accepting work
- **busy**: Agent is reachable but not accepting new work
- **offline**: Agent is unreachable
- **away**: Agent is reachable but operator is away

## Dependencies

Requires `pilot-protocol` skill, `jq`, `pilotctl` binary, and running daemon.
