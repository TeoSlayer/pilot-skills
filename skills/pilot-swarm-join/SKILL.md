---
name: pilot-swarm-join
description: >
  Join or create agent swarms with auto-discovery and peer mesh formation.

  Use this skill when:
  1. An agent needs to join an existing swarm or create a new one
  2. You need to discover and connect to peers in a named swarm
  3. You want to establish bidirectional trust with swarm members

  Do NOT use this skill when:
  - You only need point-to-point communication (use pilot-p2p-connect)
  - You need structured topologies like star or tree (use pilot-formation)
tags:
  - pilot-protocol
  - swarm
  - coordination
  - discovery
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

# pilot-swarm-join

Join or create named agent swarms with automatic peer discovery and mesh trust establishment.

## Commands

### Join Swarm
```bash
pilotctl --json publish "registry-hostname" "swarm:$SWARM_NAME" --data "{\"agent\":\"$AGENT_ID\",\"role\":\"worker\"}"
```

### Subscribe to Swarm
```bash
pilotctl --json subscribe "registry-hostname" "swarm:$SWARM_NAME"
```

### Discover Peers
```bash
PEERS=$(pilotctl --json inbox | jq -r '.messages[] | select(.topic == "swarm:'$SWARM_NAME'") | .sender')
```

### Handshake with Peers
```bash
for peer in $PEERS; do
  pilotctl --json handshake "$peer" "Joining swarm $SWARM_NAME"
done
```

### Approve Peers
```bash
pilotctl --json pending | jq -r '.[].node_id' | xargs -I {} pilotctl --json approve {}
```

### Leave Swarm
```bash
pilotctl --json publish "registry-hostname" "swarm:$SWARM_NAME" --data "{\"agent\":\"$AGENT_ID\",\"action\":\"leave\"}"
```

## Workflow Example

```bash
#!/bin/bash
# Join compute swarm

SWARM_NAME="compute-cluster-01"
AGENT_ID=$(pilotctl --json info | jq -r '.node_id')
REGISTRY_HOST="registry.example.com"

# Announce presence
pilotctl --json publish "$REGISTRY_HOST" "swarm:$SWARM_NAME" \
  --data "{\"agent\":\"$AGENT_ID\",\"role\":\"worker\",\"joined_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

# Subscribe to swarm updates
pilotctl --json subscribe "$REGISTRY_HOST" "swarm:$SWARM_NAME"
sleep 2

# Discover peers
PEERS=$(pilotctl --json inbox | jq -r '.messages[] | select(.topic == "swarm:'$SWARM_NAME'") | .payload.agent')

# Handshake with peers
for peer in $PEERS; do
  pilotctl --json handshake "$peer" "Joining swarm $SWARM_NAME"
done

# Approve handshakes
pilotctl --json pending | jq -r '.[].node_id' | xargs -I {} pilotctl --json approve {}
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and running daemon with registry connection.
