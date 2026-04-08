---
name: pilot-metrics
description: >
  Collect and aggregate agent metrics from connections, peers, and custom events.

  Use this skill when:
  1. You need to monitor agent health and performance
  2. You need to aggregate metrics across a fleet of agents
  3. You need to track connection counts, RTT, throughput
  4. You need to export metrics to monitoring systems

  Do NOT use this skill when:
  - You need application-level metrics (publish custom events instead)
  - You need persistent storage (use pilot-event-log for raw data)
  - You need real-time alerting (use pilot-alert instead)
tags:
  - pilot-protocol
  - metrics
  - monitoring
  - observability
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

# Pilot Metrics

Collect and aggregate metrics from Pilot Protocol agents.

## Commands

### Get agent info
```bash
pilotctl --json info
```
Returns node ID, address, hostname, uptime, polo score.

### Get peer list
```bash
pilotctl --json peers
```
Lists connected peers with connection time.

### Get connections
```bash
pilotctl --json connections
```
Lists active connections with state, ports, bytes sent/received.

### Subscribe to custom metrics
```bash
pilotctl --json subscribe <source-hostname> "metrics.*" [--timeout <seconds>]
```

## Workflow Example

Fleet health dashboard:

```bash
#!/bin/bash
OUTPUT_FILE="/tmp/fleet-metrics-$(date +%Y%m%d-%H%M%S).json"

echo '{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","agents":[]}' > "$OUTPUT_FILE"

agents=$(pilotctl --json trust 2>/dev/null | jq -r '.data.trusted[].hostname')

for agent in $agents; do
  ping_result=$(pilotctl --json ping "$agent" 2>/dev/null)
  rtt_ms=$(echo "$ping_result" | jq -r '.data.results[0].rtt_ms // null')

  agent_data=$(jq -n --arg hostname "$agent" --arg rtt "$rtt_ms" \
    '{hostname: $hostname, rtt_ms: ($rtt | tonumber), status: "online"}')

  jq --argjson agent "$agent_data" '.agents += [$agent]' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp"
  mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
done
```

## Dependencies

Requires pilot-protocol skill, jq, and a running daemon.
