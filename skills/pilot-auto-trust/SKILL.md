---
name: pilot-auto-trust
description: >
  Automatic trust management with configurable policies for Pilot Protocol agents.

  Use this skill when:
  1. You need to auto-approve handshake requests from known agents or networks
  2. You want policy-based trust decisions (by network membership, hostname pattern, or tag)
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

### Batch Reject by Hostname Pattern
```bash
pilotctl --json pending | jq -r '.[] | select(.hostname | test("^untrusted-")) | .node_id' | \
  xargs -I {} pilotctl --json reject {} "Untrusted source"
```

## Workflow Example

```bash
#!/bin/bash
# Auto-approve production agents from a known network

PENDING=$(pilotctl --json pending)

# Approve if address is on network 1 (prod) AND hostname matches prod pattern
echo "$PENDING" | jq -r '.[] | select((.address | startswith("1:")) and (.hostname | test("^agent-prod-"))) | .node_id' | \
while read -r NODE_ID; do
  pilotctl --json approve "$NODE_ID"
done

# Reject anything not on a known network (e.g. unrecognised remote address)
echo "$PENDING" | jq -r '.[] | select(.address | startswith("1:") | not) | .node_id' | \
while read -r NODE_ID; do
  pilotctl --json reject "$NODE_ID" "Unknown network"
done
```

## Dependencies

Requires pilot-protocol, pilotctl, and jq.
