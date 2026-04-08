---
name: pilot-heartbeat-monitor
description: >
  Detect agent failures and trigger automatic task redistribution or re-election.

  Use this skill when:
  1. You need to detect when swarm members become unreachable
  2. You want to trigger failover actions on agent failure
  3. You need health monitoring for load balancing or leader election

  Do NOT use this skill when:
  - Agents can safely fail without recovery (fire-and-forget tasks)
  - Network partitions are rare and acceptable (use simpler ping checks)
tags:
  - pilot-protocol
  - health-monitoring
  - failure-detection
  - heartbeat
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# pilot-heartbeat-monitor

Monitor agent health via periodic heartbeats and detect failures using timeout-based detection.

## Commands

### Send heartbeat to peers
```bash
pilotctl --json publish "registry-hostname" "heartbeat:$SWARM_NAME" \
  --data "{\"agent\":\"$AGENT_ID\",\"timestamp\":\"$(date -u +%s)\",\"status\":\"alive\"}"
```

### Detect failed agents
```bash
TIMEOUT=30
CURRENT_TIME=$(date -u +%s)

FAILED_AGENTS=$(pilotctl --json inbox \
  | jq --arg now "$CURRENT_TIME" --arg timeout "$TIMEOUT" \
    '[.messages[] | select(.topic == "heartbeat:'$SWARM_NAME'") | {agent: .payload.agent, last_seen: .payload.timestamp}]
    | group_by(.agent)
    | map(select(($now | tonumber) - (map(.last_seen) | max) > ($timeout | tonumber)))
    | .[].agent')
```

### Verify failure with direct ping
```bash
for agent in $FAILED_AGENTS; do
  AGENT_ADDR=$(pilotctl --json peers | jq -r '.[] | select(.node_id == "'$agent'") | .address')

  PING_RESULT=$(pilotctl --json ping "$AGENT_ADDR" --count 3 --timeout 2s)
  LOSS=$(echo "$PING_RESULT" | jq -r '.packet_loss_pct')

  if [ "$LOSS" = "100" ]; then
    echo "Agent $agent CONFIRMED DOWN"
  fi
done
```

## Workflow Example

Health monitor for worker pool with automatic task redistribution:

```bash
#!/bin/bash
SWARM_NAME="worker-pool"
HEARTBEAT_INTERVAL=5
FAILURE_TIMEOUT=15
REGISTRY_HOST="registry.example.com"

# Background: Send own heartbeats
(
  while true; do
    pilotctl --json publish "$REGISTRY_HOST" "heartbeat:$SWARM_NAME" \
      --data "{\"agent\":\"$AGENT_ID\",\"timestamp\":\"$(date -u +%s)\"}"
    sleep $HEARTBEAT_INTERVAL
  done
) &

# Monitor peer heartbeats
while true; do
  CURRENT_TIME=$(date -u +%s)

  # Detect timeouts and trigger recovery
  # ...

  sleep $HEARTBEAT_INTERVAL
done
```

## Dependencies

Requires pilot-protocol skill, jq, and bc.
