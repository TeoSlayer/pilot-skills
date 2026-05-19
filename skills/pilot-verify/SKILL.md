---
name: pilot-verify
description: >
  Verify agent identity and reachability before interacting with Pilot Protocol nodes.

  Use this skill when:
  1. You need to verify an agent's identity before trusting or connecting
  2. You want to validate hostname-to-address mapping in the registry
  3. You need to test network reachability before establishing a session

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
  version: "1.1"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Pilot Verify

Identity and reachability verification for Pilot Protocol agents. Validates authenticity, confirms hostname-to-address mapping, and tests network reachability before establishing trust.

## Essential Commands

### Lookup agent identity
```bash
# Basic lookup by hostname
pilotctl --json find agent.pilot

# Extract specific fields
pilotctl --json find agent.pilot | jq '.[0] | {hostname, address, node_id, public, public_key}'
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
pilotctl --json info | jq '{hostname, address, peers, encrypted_peers, authenticated_peers}'
```

### Verify identity matches expected fingerprint
```bash
AGENT="agent.pilot"
EXPECTED_PUBKEY="abc123..."

ACTUAL=$(pilotctl --json find "$AGENT" | jq -r '.[0].public_key')
if [ "$ACTUAL" = "$EXPECTED_PUBKEY" ]; then
  echo "Identity verified: public key matches"
else
  echo "Identity verification FAILED: pubkey mismatch (expected $EXPECTED_PUBKEY, got $ACTUAL)"
  exit 1
fi
```

## Workflow Example

Comprehensive verification before trust:

```bash
#!/bin/bash
set -e

AGENT="$1"
EXPECTED_PUBKEY="${2:-}"

echo "=== Verifying Agent: $AGENT ==="

# Step 1: Lookup identity
echo "1. Looking up identity..."
IDENTITY=$(pilotctl --json find "$AGENT" | jq '.[0]')
if [ -z "$IDENTITY" ] || [ "$IDENTITY" = "null" ]; then
  echo "FAILED: Agent not found"
  exit 1
fi

NODE_ID=$(echo "$IDENTITY" | jq -r '.node_id')
ADDRESS=$(echo "$IDENTITY" | jq -r '.address')
PUBKEY=$(echo "$IDENTITY" | jq -r '.public_key')
echo "  Node ID:    $NODE_ID"
echo "  Address:    $ADDRESS"
echo "  Public key: ${PUBKEY:0:16}..."

# Step 2: Verify public-key fingerprint if expected value provided
if [ -n "$EXPECTED_PUBKEY" ]; then
  echo "2. Checking public-key fingerprint..."
  if [ "$PUBKEY" != "$EXPECTED_PUBKEY" ]; then
    echo "FAILED: Public-key mismatch"
    exit 1
  fi
  echo "  PASSED"
fi

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
