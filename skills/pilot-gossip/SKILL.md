---
name: pilot-gossip
description: >
  Gossip protocol for eventually-consistent shared state propagation across swarms.

  Use this skill when:
  1. You need eventually-consistent state replication without coordination
  2. Agents should share updates with random subsets of peers
  3. You want epidemic-style information dissemination

  Do NOT use this skill when:
  - You need strong consistency (use pilot-consensus)
  - You need ordered message delivery (use leader-based broadcast)
tags:
  - pilot-protocol
  - gossip
  - eventual-consistency
  - state-replication
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

# pilot-gossip

Implement gossip protocols for eventually-consistent state propagation in agent swarms.

This skill enables agents to share state updates by randomly selecting peers and exchanging information, achieving eventual consistency without centralized coordination.

## Commands

### Publish state update to random peers
```bash
FANOUT=3
PEERS=$(pilotctl --json peers --search "swarm:$SWARM_NAME" | jq -r '.[].address' | shuf -n $FANOUT)

for peer in $PEERS; do
  pilotctl --json send-message "$peer" \
    --data "{\"type\":\"gossip_push\",\"version\":$STATE_VERSION,\"state\":$STATE_DATA,\"sender\":\"$AGENT_ID\",\"timestamp\":\"$(date -u +%s)\"}" &
done
wait
```

### Merge received state updates
```bash
GOSSIP_MSGS=$(pilotctl --json received | jq '[.messages[] | select(.payload.type == "gossip_push")]')

for msg in $(echo "$GOSSIP_MSGS" | jq -r '.[] | @base64'); do
  PAYLOAD=$(echo "$msg" | base64 -d)
  REMOTE_VERSION=$(echo "$PAYLOAD" | jq -r '.payload.version')

  if [ "$REMOTE_VERSION" -gt "$MY_VERSION" ]; then
    MY_STATE=$(echo "$MY_STATE $REMOTE_STATE" | jq -s '.[0] * .[1]')
    MY_VERSION=$REMOTE_VERSION
  fi
done
```

## Workflow Example

Distributed key-value store with gossip replication:

```bash
#!/bin/bash
SWARM_NAME="kv-store-cluster"
AGENT_ID=$(pilotctl --json info | jq -r '.node_id')

# Gossip loop
for round in $(seq 1 10); do
  # Push to random peers
  PEERS=$(pilotctl --json peers --search "swarm:$SWARM_NAME" | jq -r '.[].address' | shuf -n 3)

  for peer in $PEERS; do
    pilotctl --json send-message "$peer" \
      --data "{\"type\":\"gossip_push\",\"version\":$MY_VERSION,\"state\":$MY_STATE,\"sender\":\"$AGENT_ID\"}" &
  done
  wait

  sleep 5
done
```

## Dependencies

Requires pilot-protocol skill, jq, shuf, and base64.
