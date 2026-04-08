---
name: pilot-swarm-config
description: >
  Distributed configuration management for agent swarms with versioned updates.

  Use this skill when:
  1. Multiple agents need to share configuration settings
  2. You need to push config updates to all swarm members
  3. You want versioned config with rollback capability

  Do NOT use this skill when:
  - Configuration is static and set at startup (use local config files)
  - Each agent has unique config (no sharing needed)
tags:
  - pilot-protocol
  - configuration
  - swarm-coordination
  - state-management
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

# pilot-swarm-config

Manage shared configuration across agent swarms with versioning, atomic updates, and rollback support.

## Essential Commands

### Publish configuration update
```bash
CONFIG_VERSION=$(date +%s)
CONFIG_DATA='{"max_workers":10,"timeout_ms":5000,"log_level":"info"}'

pilotctl --json publish "registry-hostname" "config:$SWARM_NAME" \
  --data "{\"type\":\"config_update\",\"version\":$CONFIG_VERSION,\"config\":$CONFIG_DATA}"
```

### Subscribe to configuration updates
```bash
pilotctl --json subscribe "registry-hostname" "config:$SWARM_NAME"
```

### Apply configuration locally
```bash
LATEST_CONFIG=$(pilotctl --json inbox \
  | jq '[.messages[] | select(.topic == "config:'$SWARM_NAME'" and .payload.type == "config_update")] | sort_by(.payload.version) | last')

CONFIG_VERSION=$(echo "$LATEST_CONFIG" | jq -r '.payload.version')
CONFIG_DATA=$(echo "$LATEST_CONFIG" | jq -r '.payload.config')

echo "$CONFIG_DATA" > /tmp/swarm-config.json
echo "$CONFIG_VERSION" > /tmp/swarm-config-version.txt
```

### Validate configuration
```bash
# Basic validation
VALID=$(echo "$CONFIG_DATA" | jq 'has("max_workers") and has("timeout_ms")')

if [ "$VALID" = "true" ]; then
  echo "Config validation passed"
else
  echo "Config validation FAILED"
  exit 1
fi
```

### Rollback to previous version
```bash
CURRENT_VERSION=$(cat /tmp/swarm-config-version.txt)
PREVIOUS_CONFIG=$(pilotctl --json inbox \
  | jq '[.messages[] | select(.topic == "config:'$SWARM_NAME'" and .payload.type == "config_update" and .payload.version < '$CURRENT_VERSION')] | sort_by(.payload.version) | last')

PREV_VERSION=$(echo "$PREVIOUS_CONFIG" | jq -r '.payload.version')
PREV_DATA=$(echo "$PREVIOUS_CONFIG" | jq -r '.payload.config')

echo "$PREV_DATA" > /tmp/swarm-config.json
echo "$PREV_VERSION" > /tmp/swarm-config-version.txt
```

### Track compliance
```bash
# Agents report applied version
pilotctl --json publish "registry-hostname" "config:status:$SWARM_NAME" \
  --data "{\"agent\":\"$AGENT_ID\",\"applied_version\":$CONFIG_VERSION}"

# Coordinator checks compliance
COMPLIANCE=$(pilotctl --json inbox \
  | jq '[.messages[] | select(.topic == "config:status:'$SWARM_NAME'")] | group_by(.payload.applied_version) | map({version: .[0].payload.applied_version, count: length})')
```

## Workflow Example

Agent config subscriber:

```bash
#!/bin/bash
set -e

SWARM_NAME="worker-pool"
CONFIG_CHANNEL="config:$SWARM_NAME"
STATUS_CHANNEL="config:status:$SWARM_NAME"
REGISTRY_HOST="registry.example.com"

pilotctl --json subscribe "$REGISTRY_HOST" "$CONFIG_CHANNEL"

CURRENT_VERSION=0
[ -f /tmp/swarm-config-version.txt ] && CURRENT_VERSION=$(cat /tmp/swarm-config-version.txt)

while true; do
  LATEST=$(pilotctl --json inbox \
    | jq '[.messages[] | select(.topic == "'$CONFIG_CHANNEL'" and .payload.type == "config_update")] | sort_by(.payload.version) | last')

  if [ -n "$LATEST" ] && [ "$LATEST" != "null" ]; then
    LATEST_VERSION=$(echo "$LATEST" | jq -r '.payload.version')

    if [ "$LATEST_VERSION" -gt "$CURRENT_VERSION" ]; then
      echo "Applying config version $LATEST_VERSION"
      CONFIG_DATA=$(echo "$LATEST" | jq -r '.payload.config')

      echo "$CONFIG_DATA" > /tmp/swarm-config.json
      echo "$LATEST_VERSION" > /tmp/swarm-config-version.txt

      # Report compliance
      pilotctl --json publish "$REGISTRY_HOST" "$STATUS_CHANNEL" \
        --data "{\"agent\":\"$AGENT_ID\",\"applied_version\":$LATEST_VERSION}"

      CURRENT_VERSION=$LATEST_VERSION
    fi
  fi
  sleep 5
done
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, and `jq` for JSON parsing.
