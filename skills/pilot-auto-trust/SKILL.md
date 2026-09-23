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

Pending entries carry only `node_id`, `public_key`, `justification` and
`received_at` (under `.data.pending[]`) — no hostname and no address. To
apply a policy on hostname or network, resolve each requester in the
registry with `lookup` first. A requester whose record the registry won't
return (for example a private node) gets no hostname or networks, so these
rules leave it pending for manual review.

### List Pending Requests
```bash
pilotctl --json pending
```

### Auto-Approve by Network
```bash
pilotctl --json pending | jq -r '.data.pending[].node_id' | while read -r NODE_ID; do
  if pilotctl --json lookup "$NODE_ID" | jq -e 'any(.data.networks[]?; . == 1)' >/dev/null; then
    pilotctl --json approve "$NODE_ID"
  fi
done
```

### Auto-Approve by Hostname Pattern
```bash
pilotctl --json pending | jq -r '.data.pending[].node_id' | while read -r NODE_ID; do
  HOST=$(pilotctl --json lookup "$NODE_ID" | jq -r '.data.hostname // empty')
  case "$HOST" in
    agent-prod-*) pilotctl --json approve "$NODE_ID" ;;
  esac
done
```

Hostnames are first-come in the registry — anyone can claim an unused
`agent-prod-…` name — so pair a hostname rule with a network or public-key
check before approving anything sensitive.

### Batch Reject by Hostname Pattern
```bash
pilotctl --json pending | jq -r '.data.pending[].node_id' | while read -r NODE_ID; do
  HOST=$(pilotctl --json lookup "$NODE_ID" | jq -r '.data.hostname // empty')
  case "$HOST" in
    untrusted-*) pilotctl --json reject "$NODE_ID" "Untrusted source" ;;
  esac
done
```

## Workflow Example

```bash
#!/bin/bash
# Auto-approve production agents from a known network; reject requesters
# the registry places on other networks; leave unresolvable ones pending.

pilotctl --json pending | jq -r '.data.pending[].node_id' | while read -r NODE_ID; do
  RECORD=$(pilotctl --json lookup "$NODE_ID" 2>/dev/null) || continue   # unresolvable: manual review
  HOST=$(echo "$RECORD" | jq -r '.data.hostname // empty')
  ON_PROD=$(echo "$RECORD" | jq -r 'any(.data.networks[]?; . == 1)')

  if [ "$ON_PROD" = "true" ]; then
    case "$HOST" in
      agent-prod-*) pilotctl --json approve "$NODE_ID" ;;
    esac
  else
    pilotctl --json reject "$NODE_ID" "Unknown network"
  fi
done
```

## Dependencies

Requires pilot-protocol, pilotctl, and jq.
