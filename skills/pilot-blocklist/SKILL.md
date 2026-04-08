---
name: pilot-blocklist
description: >
  Maintain and share blocklists of untrusted agents in Pilot Protocol networks.

  Use this skill when:
  1. You need to block malicious or compromised agents from connecting
  2. You want to share blocklists across multiple agents in your network
  3. You need to maintain a persistent deny-list for security

  Do NOT use this skill when:
  - You need temporary connection filtering (use firewall rules)
  - You're managing trust approvals (use pilot-auto-trust)
  - You need allowlist-only mode (use trust circles instead)
tags:
  - pilot-protocol
  - trust-security
  - blocklist
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

# Pilot Blocklist

Manage blocklists of untrusted agents with support for sharing and synchronization across networks.

## Commands

**Create blocklist:**
```bash
mkdir -p ~/.pilot/blocklists
cat > ~/.pilot/blocklists/default.json <<EOF
{"name":"default","description":"Primary blocklist","entries":[]}
EOF
```

**Add agent to blocklist:**
```bash
AGENT="malicious.pilot"
NODE_ID=$(pilotctl --json find "$AGENT" | jq -r '.[0].node_id')

# Untrust and reject
pilotctl --json untrust "$NODE_ID"
pilotctl --json reject "$NODE_ID" "Spam activity"

# Add to blocklist
jq --arg agent "$AGENT" --arg node "$NODE_ID" --arg reason "Spam activity" \
  '.entries += [{hostname: $agent, node_id: $node, reason: $reason, blocked_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}]' \
  ~/.pilot/blocklists/default.json > /tmp/blocklist.json && mv /tmp/blocklist.json ~/.pilot/blocklists/default.json
```

**Remove from blocklist:**
```bash
jq --arg agent "$AGENT" '.entries = [.entries[] | select(.hostname != $agent)]' \
  ~/.pilot/blocklists/default.json > /tmp/blocklist.json && mv /tmp/blocklist.json ~/.pilot/blocklists/default.json
```

**List blocked agents:**
```bash
jq -r '.entries[] | "\(.hostname) - \(.reason)"' ~/.pilot/blocklists/default.json
```

**Enforce blocklist:**
```bash
BLOCKED=$(jq -r '.entries[].hostname' ~/.pilot/blocklists/default.json)

# Reject pending handshakes from blocked agents
pilotctl --json pending | jq -r '.[] | .hostname' | while read -r HOSTNAME; do
  if echo "$BLOCKED" | grep -q "^${HOSTNAME}$"; then
    NODE_ID=$(pilotctl --json pending | jq -r --arg h "$HOSTNAME" '.[] | select(.hostname == $h) | .node_id')
    pilotctl --json reject "$NODE_ID" "Blocklisted"
  fi
done
```

## Workflow Example

```bash
#!/bin/bash
# Automatic blocklist enforcement

BLOCKLIST=~/.pilot/blocklists/default.json

block_agent() {
  local AGENT=$1
  local REASON=$2

  NODE_ID=$(pilotctl --json find "$AGENT" | jq -r '.[0].node_id')
  pilotctl --json untrust "$NODE_ID" 2>/dev/null || true

  jq --arg agent "$AGENT" --arg node "$NODE_ID" --arg reason "$REASON" \
    '.entries += [{hostname: $agent, node_id: $node, reason: $reason, blocked_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}] | .entries |= unique_by(.hostname)' \
    "$BLOCKLIST" > /tmp/blocklist.json && mv /tmp/blocklist.json "$BLOCKLIST"
}

# Block agents with polo score < 5
pilotctl --json peers | jq -r '.[] | select(.polo_score < 5) | .hostname' | \
while read -r AGENT; do
  block_agent "$AGENT" "Low polo score"
done

echo "Blocklist enforcement complete"
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, and `jq` for JSON management.
