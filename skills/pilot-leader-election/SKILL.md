---
name: pilot-leader-election
description: >
  Elect a coordinator with automatic failover using heartbeat-based leader election.

  Use this skill when:
  1. A swarm needs a single coordinator for decision making
  2. You need automatic failover when the current leader fails
  3. You want to avoid split-brain with deterministic tie-breaking

  Do NOT use this skill when:
  - All agents need equal voting power (use pilot-consensus)
  - You need decentralized decision making (use pilot-gossip)
tags:
  - pilot-protocol
  - leader-election
  - coordination
  - failover
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

# pilot-leader-election

Implement leader election protocols with automatic failover detection.

## Commands

### Announce candidacy
```bash
pilotctl --json publish "registry-hostname" "election:$ELECTION_GROUP" \
  --data "{\"type\":\"election\",\"candidate\":\"$AGENT_ID\",\"priority\":$PRIORITY,\"term\":$TERM}"
```

### Declare victory as leader
```bash
pilotctl --json publish "registry-hostname" "election:$ELECTION_GROUP" \
  --data "{\"type\":\"leader\",\"leader\":\"$AGENT_ID\",\"term\":$TERM,\"elected_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
```

### Send leader heartbeat
```bash
pilotctl --json publish "registry-hostname" "election:$ELECTION_GROUP" \
  --data "{\"type\":\"heartbeat\",\"leader\":\"$AGENT_ID\",\"term\":$TERM,\"timestamp\":\"$(date -u +%s)\"}"
```

### Detect leader failure
```bash
LAST_HEARTBEAT=$(pilotctl --json inbox \
  | jq -r '[.messages[] | select(.topic == "election:'$ELECTION_GROUP'" and .payload.type == "heartbeat")] | sort_by(.payload.timestamp) | last | .payload.timestamp')

ELAPSED=$(( $(date -u +%s) - LAST_HEARTBEAT ))

if [ "$ELAPSED" -gt 10 ]; then
  echo "Leader timeout, starting election"
fi
```

## Workflow Example

Bully algorithm with priority-based election:

```bash
#!/bin/bash
ELECTION_GROUP="task-coordinator"
AGENT_ID=$(pilotctl --json info | jq -r '.node_id')
PRIORITY=$(echo -n "$AGENT_ID" | cksum | cut -d' ' -f1)
REGISTRY_HOST="registry.example.com"

# Announce candidacy
pilotctl --json publish "$REGISTRY_HOST" "election:$ELECTION_GROUP" \
  --data "{\"type\":\"election\",\"candidate\":\"$AGENT_ID\",\"priority\":$PRIORITY,\"term\":$TERM}"

# Wait and check if highest priority
sleep 10

HIGHEST=$(pilotctl --json inbox \
  | jq -r '[.messages[] | select(.topic == "election:'$ELECTION_GROUP'" and .payload.type == "election")] | sort_by(.payload.priority) | last | .payload.candidate')

if [ "$HIGHEST" = "$AGENT_ID" ]; then
  pilotctl --json publish "$REGISTRY_HOST" "election:$ELECTION_GROUP" \
    --data "{\"type\":\"leader\",\"leader\":\"$AGENT_ID\",\"term\":$TERM}"
fi
```

## Dependencies

Requires pilot-protocol skill, jq, and cksum.
