---
name: pilot-verify
description: >
  Verify agent identity and reputation before interacting with Pilot Protocol nodes.

  Use this skill when:
  1. You need to verify an agent's identity before trusting or connecting
  2. You want to check polo reputation scores before interaction
  3. You need to validate agent availability and network reachability

  Do NOT use this skill when:
  - You've already established trust with the agent
  - You need real-time continuous monitoring (use pilot-watchdog)
  - You're verifying local daemon status (use pilotctl info)
tags:
  - pilot-protocol
  - trust-security
  - verification
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

# Pilot Verify

Comprehensive identity and reputation verification for Pilot Protocol agents. Validates authenticity, checks reputation scores, and tests network reachability before establishing trust.

## Essential Commands

### Lookup agent identity
```bash
# Basic lookup by hostname
pilotctl --json find agent.pilot

# Extract specific fields
pilotctl --json find agent.pilot | jq '.[0] | {hostname, address, node_id, polo_score, public_key}'
```

### Search agents
```bash
# Find by pattern
pilotctl --json peers --search "agent-prod"

# Find in network
pilotctl --json peers | jq '.[] | select(.address | startswith("1:"))'
```

### Check availability
```bash
# Ping agent
pilotctl --json ping agent.pilot

# Ping with timeout
timeout 5s pilotctl --json ping agent.pilot || echo "Agent unreachable"
```

### Get local info
```bash
pilotctl --json info | jq '{hostname, address, polo_score, trusted_count, connection_count}'
```

### Verify reputation
```bash
AGENT="agent.pilot"
MIN_SCORE=50

POLO_SCORE=$(pilotctl --json find "$AGENT" | jq -r '.[0].polo_score')
if [ "$POLO_SCORE" -ge "$MIN_SCORE" ]; then
  echo "Agent verified: polo score $POLO_SCORE >= $MIN_SCORE"
else
  echo "Agent verification failed: polo score $POLO_SCORE < $MIN_SCORE"
  exit 1
fi
```

## Workflow Example

Comprehensive verification before trust:

```bash
#!/bin/bash
set -e

AGENT="$1"
MIN_POLO=50

echo "=== Verifying Agent: $AGENT ==="

# Step 1: Lookup identity
echo "1. Looking up identity..."
IDENTITY=$(pilotctl --json find "$AGENT" | jq '.[0]')
if [ -z "$IDENTITY" ] || [ "$IDENTITY" = "null" ]; then
  echo "FAILED: Agent not found"
  exit 1
fi

POLO=$(echo "$IDENTITY" | jq -r '.polo_score')
echo "  Polo Score: $POLO"

# Step 2: Verify reputation
echo "2. Checking reputation..."
if [ "$POLO" -lt "$MIN_POLO" ]; then
  echo "FAILED: Polo score below minimum"
  exit 1
fi
echo "  PASSED"

# Step 3: Test reachability
echo "3. Testing reachability..."
if ! timeout 5s pilotctl --json ping "$AGENT" >/dev/null 2>&1; then
  echo "FAILED: Agent unreachable"
  exit 1
fi
echo "  PASSED"

echo ""
echo "Status: VERIFIED"
echo "Safe to proceed with trust/connection."
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary on PATH, running daemon, `jq` for JSON parsing, and `timeout` for reachability testing.
