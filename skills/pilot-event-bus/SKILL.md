---
name: pilot-event-bus
description: >
  Multi-agent event aggregation on shared topics for coordinated workflows.

  Use this skill when:
  1. You need to aggregate events from multiple agents on a shared topic
  2. You need to broadcast events to all subscribed agents
  3. You need to coordinate state changes across a fleet of agents
  4. You need to implement fan-out messaging patterns

  Do NOT use this skill when:
  - You need point-to-point messaging (use pilot-protocol connect instead)
  - You need persistent storage (use pilot-event-log instead)
  - You need filtered or transformed events (use pilot-event-filter instead)
tags:
  - pilot-protocol
  - pub-sub
  - event-bus
  - coordination
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
  All participating agents must have mutual trust established.
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

# Pilot Event Bus

Multi-agent event aggregation using Pilot Protocol's built-in pub/sub on port 1002.

## Commands

### Publish Event
```bash
pilotctl --json publish <target-hostname> <topic> --data <payload>
```

### Subscribe to Events
```bash
pilotctl --json subscribe <target-hostname> <topic> [--timeout <seconds>]
```

### List Trusted Agents
```bash
pilotctl --json trust
```

### Find Agent
```bash
pilotctl --json find <hostname>
```

### Establish Trust
```bash
pilotctl --json handshake <hostname> "reason for trust request"
```

## Workflow Example

```bash
#!/bin/bash
# Fleet coordination

pilotctl --json trust | jq -r '.data.trusted[].hostname'

pilotctl --json subscribe fleet-coordinator "tasks.assigned.*" --timeout 300 > /tmp/events.json &

pilotctl --json publish fleet-coordinator "tasks.assigned.worker-1" \
  --data "{\"task_id\":\"task-123\",\"assigned_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

jq -r '.data.events[] | "\(.timestamp): \(.topic) -> \(.data)"' /tmp/events.json
```

## Topic Naming

- `category.subcategory.event` (dotted hierarchy)
- Examples: `tasks.assigned.worker-1`, `metrics.cpu.usage`, `alerts.error.database`
- Wildcards: `tasks.*`, `alerts.error.*`, `*`

## Dependencies

Requires pilot-protocol skill, pilotctl, running daemon, and mutual trust between agents.
