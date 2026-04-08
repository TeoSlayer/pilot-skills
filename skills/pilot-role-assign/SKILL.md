---
name: pilot-role-assign
description: >
  Assign and manage hierarchical roles within a swarm for coordinated task distribution.

  Use this skill when:
  1. Agents need different responsibilities (leader, worker, coordinator)
  2. You want capability-based role assignment (GPU workers, CPU workers)
  3. You need dynamic role reassignment on failures or scaling events

  Do NOT use this skill when:
  - All agents are homogeneous (no role differentiation needed)
  - Roles are static and configured at startup (use tags)
tags:
  - pilot-protocol
  - role-management
  - swarm-organization
  - coordination
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

# pilot-role-assign

Dynamically assign and manage roles in agent swarms using capability-based matching.

## Commands

### Advertise agent capabilities
```bash
pilotctl --json publish "registry-hostname" "capabilities:$SWARM_NAME" \
  --data "{\"agent\":\"$AGENT_ID\",\"capabilities\":{\"cpu_cores\":16,\"ram_gb\":64,\"gpu\":true}}"
```

### Assign role to agent
```bash
pilotctl --json send-message "$AGENT_ADDRESS" \
  --data "{\"type\":\"role_assignment\",\"role\":\"$ROLE_NAME\",\"assigned_by\":\"$COORDINATOR_ID\"}"

pilotctl --json publish "registry-hostname" "roles:$SWARM_NAME" \
  --data "{\"agent\":\"$AGENT_ID\",\"role\":\"$ROLE_NAME\",\"assigned_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
```

### Query current role distribution
```bash
ROLE_DIST=$(pilotctl --json inbox \
  | jq '[.messages[] | select(.topic == "roles:'$SWARM_NAME'")] | group_by(.payload.role) | map({role: .[0].payload.role, count: length})')
echo "$ROLE_DIST" | jq '.'
```

## Workflow Example

Coordinator assigns roles based on capabilities:

```bash
#!/bin/bash
SWARM_NAME="compute-swarm"
REGISTRY_HOST="registry.example.com"

# Get agent capabilities
CAPABILITIES=$(pilotctl --json inbox | jq '[.messages[] | select(.topic == "capabilities:'$SWARM_NAME'") | .payload]')

for agent_data in $(echo "$CAPABILITIES" | jq -r '.[] | @base64'); do
  AGENT=$(echo "$agent_data" | base64 -d | jq -r '.agent')
  HAS_GPU=$(echo "$agent_data" | base64 -d | jq -r '.capabilities.gpu // false')

  if [ "$HAS_GPU" = "true" ]; then
    ROLE="gpu_worker"
  else
    ROLE="worker"
  fi

  AGENT_ADDR=$(pilotctl --json peers | jq -r '.[] | select(.node_id == "'$AGENT'") | .address')

  pilotctl --json send-message "$AGENT_ADDR" \
    --data "{\"type\":\"role_assignment\",\"role\":\"$ROLE\"}" &
done
wait
```

## Dependencies

Requires pilot-protocol skill, jq, and base64.
