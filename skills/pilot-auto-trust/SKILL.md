---
name: pilot-auto-trust
description: >
  Automatic trust management with configurable policies for Pilot Protocol agents.

  Use this skill when:
  1. You need to auto-approve handshake requests from known agents or networks
  2. You want policy-based trust decisions (e.g., auto-trust high polo scores)
  3. You need to batch-process pending trust requests

  Do NOT use this skill when:
  - You need manual review of every trust request
  - You're dealing with unknown or potentially malicious agents
  - You need fine-grained per-agent trust policies
tags:
  - pilot-protocol
  - trust-security
  - automation
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

# Pilot Auto-Trust

Automated trust management for Pilot Protocol with policy-based decision making.

## Commands

### List Pending Requests
```bash
pilotctl --json pending
```

### Auto-Approve by Polo Score
```bash
pilotctl --json pending | jq -r '.[] | select(.polo_score >= 50) | .node_id' | \
  xargs -I {} pilotctl --json approve {}
```

### Auto-Approve by Network
```bash
pilotctl --json pending | jq -r '.[] | select(.address | startswith("1:")) | .node_id' | \
  xargs -I {} pilotctl --json approve {}
```

### Auto-Approve by Hostname Pattern
```bash
pilotctl --json pending | jq -r '.[] | select(.hostname | test("^agent-prod-")) | .node_id' | \
  xargs -I {} pilotctl --json approve {}
```

### Batch Reject Low-Reputation
```bash
pilotctl --json pending | jq -r '.[] | select(.polo_score < 20) | .node_id' | \
  xargs -I {} pilotctl --json reject {} "Low reputation score"
```

## Workflow Example

```bash
#!/bin/bash
# Auto-approve production agents with high reputation

PENDING=$(pilotctl --json pending)

# Approve if polo >= 50 AND hostname matches prod pattern
echo "$PENDING" | jq -r '.[] | select(.polo_score >= 50 and (.hostname | test("^agent-prod-"))) | .node_id' | \
while read -r NODE_ID; do
  pilotctl --json approve "$NODE_ID"
done

# Reject if polo < 20
echo "$PENDING" | jq -r '.[] | select(.polo_score < 20) | .node_id' | \
while read -r NODE_ID; do
  pilotctl --json reject "$NODE_ID" "Low polo score"
done
```

## Dependencies

Requires pilot-protocol, pilotctl, and jq.
