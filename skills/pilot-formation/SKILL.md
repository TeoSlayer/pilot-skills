---
name: pilot-formation
description: >
  Deploy predefined network topologies (star, ring, mesh, tree) for structured swarms.

  Use this skill when:
  1. You need specific communication patterns (star coordinator, ring consensus)
  2. You want to minimize connection overhead with structured topologies
  3. You need hierarchical organization (tree) for scaling

  Do NOT use this skill when:
  - Ad-hoc peer discovery is sufficient (use pilot-swarm-join)
  - Topology changes frequently (use dynamic mesh)
tags:
  - pilot-protocol
  - topology
  - network-formation
  - swarm-structure
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

# pilot-formation

Deploy structured network topologies with automatic peer handshaking and trust establishment. Supports star (hub-and-spoke), ring (circular), mesh (all-to-all), tree (hierarchical), and line (chain) formations.

## Commands

**Deploy star (hub connects to all spokes):**
```bash
WORKERS=$(pilotctl --json peers --search "role:worker" | jq -r '.[].hostname')
for worker in $WORKERS; do
  pilotctl --json handshake "$worker" "Forming star topology"
  sleep 1
  NODE_ID=$(pilotctl --json pending | jq -r '.pending[] | select(.hostname == "'"$worker"'") | .node_id')
  [ -n "$NODE_ID" ] && pilotctl --json approve "$NODE_ID"
done
```

**Deploy ring (circular connections):**
```bash
AGENTS=$(pilotctl --json peers --search "swarm:$SWARM_NAME" | jq -r 'sort_by(.node_id) | .[].address')
# Connect to next agent in sorted order (implementation in workflow)
```

**Deploy mesh (all-to-all):**
```bash
ALL_PEERS=$(pilotctl --json peers --search "swarm:$SWARM_NAME" | jq -r '.[].address')
for peer in $ALL_PEERS; do
  pilotctl --json handshake "$peer" "Forming mesh topology" &
done
wait

# Approve all pending handshakes
PENDING=$(pilotctl --json pending | jq -r '.[].node_id')
for peer in $PENDING; do
  pilotctl --json approve "$peer" &
done
wait
```

## Workflow Example

```bash
#!/bin/bash
# Deploy star topology

SWARM_NAME="task-swarm"
MY_ADDR=$(pilotctl --json info | jq -r '.address')
REGISTRY_HOST="registry.example.com"

# Get swarm members
SWARM_MEMBERS=$(pilotctl --json peers --search "swarm:$SWARM_NAME" | jq -r '.[].address')

echo "Deploying star topology (hub: $MY_ADDR)"

# Hub connects to all spokes
for worker in $SWARM_MEMBERS; do
  if [ "$worker" != "$MY_ADDR" ]; then
    echo "Connecting to spoke: $worker"
    pilotctl --json handshake "$worker" "Forming star topology"
    sleep 1
    NODE_ID=$(pilotctl --json pending | jq -r '.pending[] | select(.hostname == "'"$worker"'") | .node_id')
    [ -n "$NODE_ID" ] && pilotctl --json approve "$NODE_ID"
  fi
done

# Publish topology
pilotctl --json publish "$REGISTRY_HOST" "topology:$SWARM_NAME" \
  --data "{\"type\":\"star\",\"hub\":\"$MY_ADDR\",\"formed_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

echo "Star topology complete"
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, and `jq` for JSON parsing.
