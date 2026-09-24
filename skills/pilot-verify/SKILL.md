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

Every `pilotctl --json` command prints `{"status":"ok","data":{...}}` on
success, so the fields below are read from `.data`. On failure it exits
non-zero and prints `{"status":"error","code":...}` on stderr instead.

### Lookup agent identity
```bash
# Resolve a hostname to its node ID and address
pilotctl --json find agent-prod-1

# Extract specific fields (find returns hostname, node_id, address, public)
pilotctl --json find agent-prod-1 | jq '.data | {hostname, address, node_id, public}'

# Full registry record, including the public key (lookup takes a hostname, node ID or address)
pilotctl --json lookup agent-prod-1 | jq '.data | {node_id, hostname, public_key, public, networks}'
```

### Search agents
```bash
# peers --search matches node-ID substrings (peer entries carry no hostname or address)
pilotctl --json peers --search 1234

# Connected peers that belong to network 1, read from each peer's registry record
pilotctl --json peers | jq -r '.data.peers[].node_id' | while read -r ID; do
  pilotctl --json lookup "$ID" | jq -r 'select(any(.data.networks[]?; . == 1)) | .data.node_id'
done
```

### Check availability
```bash
# Ping agent: each .data.results[] entry is one probe. A failed probe has "error";
# one that connected but lost its echo has "error" AND "rtt_ms", so never treat
# rtt_ms as success. A successful probe has no "error" (and has "bytes").
pilotctl --json ping agent-prod-1 --count 1

# Reachable = at least one probe without an error. Count them rather than trust
# the exit status alone: with --count > 1, ping can exit 0 after its overall
# timeout even when every probe failed. A ping that fails outright prints
# nothing on stdout, which also makes jq -e fail.
pilotctl --json ping agent-prod-1 --count 1 2>/dev/null | jq -e '[.data.results[]? | select(.error == null)] | length > 0' >/dev/null || echo "Agent unreachable"
```

### Get local info
```bash
pilotctl --json info | jq '.data | {hostname, address, peers, encrypted_peers, authenticated_peers}'
```

### Verify identity matches expected public key
```bash
AGENT="agent-prod-1"
EXPECTED_PUBKEY="abc123..."   # base64, as printed by lookup

# find does not return the public key; lookup does
ACTUAL=$(pilotctl --json lookup "$AGENT" | jq -r '.data.public_key // empty')
if [ -n "$ACTUAL" ] && [ "$ACTUAL" = "$EXPECTED_PUBKEY" ]; then
  echo "Identity verified: public key matches"
else
  echo "Identity verification FAILED: pubkey mismatch (expected $EXPECTED_PUBKEY, got ${ACTUAL:-nothing})"
  exit 1
fi
```

## Workflow Example

Comprehensive verification before trust:

```bash
#!/bin/bash
set -euo pipefail

AGENT="$1"
EXPECTED_PUBKEY="${2:-}"

echo "=== Verifying Agent: $AGENT ==="

# Step 1: Look up the registry record (exits non-zero if the name is not registered)
echo "1. Looking up identity..."
if ! RECORD=$(pilotctl --json lookup "$AGENT"); then
  echo "FAILED: Agent not found"
  exit 1
fi

NODE_ID=$(echo "$RECORD" | jq -r '.data.node_id')
ADDRESS=$(echo "$RECORD" | jq -r '.data.address')
PUBKEY=$(echo "$RECORD" | jq -r '.data.public_key // empty')
echo "  Node ID:    $NODE_ID"
echo "  Address:    $ADDRESS"
echo "  Public key: ${PUBKEY:0:16}..."

# Step 2: Verify the public key if an expected value was provided
if [ -n "$EXPECTED_PUBKEY" ]; then
  echo "2. Checking public key..."
  if [ "$PUBKEY" != "$EXPECTED_PUBKEY" ]; then
    echo "FAILED: Public-key mismatch"
    exit 1
  fi
  echo "  PASSED"
fi

# Step 3: Test reachability (count probes without an error, see above)
echo "3. Testing reachability..."
if ! pilotctl --json ping "$AGENT" --count 1 2>/dev/null | jq -e '[.data.results[]? | select(.error == null)] | length > 0' >/dev/null; then
  echo "FAILED: Agent unreachable"
  exit 1
fi
echo "  PASSED"

echo ""
echo "Status: VERIFIED"
echo "Safe to proceed with trust/connection."
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary on PATH, running daemon, and `jq` for JSON parsing.
