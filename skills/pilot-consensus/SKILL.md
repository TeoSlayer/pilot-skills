---
name: pilot-consensus
description: >
  Distributed voting and agreement protocols for multi-agent decision making.

  Use this skill when:
  1. Multiple agents need to agree on a value or decision
  2. You need Byzantine fault-tolerant consensus in a swarm
  3. You want to coordinate distributed transactions or state changes

  Do NOT use this skill when:
  - A single leader can make decisions (use pilot-leader-election)
  - You only need eventual consistency (use pilot-gossip)
tags:
  - pilot-protocol
  - consensus
  - voting
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

# pilot-consensus

Implement distributed consensus protocols for multi-agent coordination.

## Commands

### Propose a value
```bash
PROPOSAL_ID=$(uuidgen)
pilotctl --json publish "registry-hostname" "consensus:$CONSENSUS_GROUP" \
  --data "{\"type\":\"proposal\",\"id\":\"$PROPOSAL_ID\",\"proposer\":\"$AGENT_ID\",\"value\":$PROPOSAL_VALUE,\"term\":$CURRENT_TERM}"
```

### Vote on a proposal
```bash
pilotctl --json send-message "$PROPOSER_ADDRESS" \
  --data "{\"type\":\"vote\",\"proposal_id\":\"$PROPOSAL_ID\",\"voter\":\"$AGENT_ID\",\"approve\":true,\"term\":$CURRENT_TERM}"
```

### Collect votes and check quorum
```bash
VOTES=$(pilotctl --json received | jq '[.messages[] | select(.payload.type == "vote" and .payload.proposal_id == "'$PROPOSAL_ID'")]')
APPROVALS=$(echo "$VOTES" | jq '[.[] | select(.payload.approve == true)] | length')
QUORUM=$(( ($TOTAL_VOTERS / 2) + 1 ))

if [ "$APPROVALS" -ge "$QUORUM" ]; then
  echo "Consensus reached"
fi
```

## Workflow Example

Three-phase consensus protocol:

```bash
#!/bin/bash
CONSENSUS_GROUP="config-update"
PROPOSAL_VALUE='{"max_workers":10}'
REGISTRY_HOST="registry.example.com"

# Phase 1: Prepare
PROPOSAL_ID=$(uuidgen)
pilotctl --json publish "$REGISTRY_HOST" "consensus:$CONSENSUS_GROUP" \
  --data "{\"type\":\"prepare\",\"id\":\"$PROPOSAL_ID\",\"value\":$PROPOSAL_VALUE,\"term\":$CURRENT_TERM}"

# Phase 2: Vote
sleep 3
VOTES=$(pilotctl --json received | jq '[.messages[] | select(.payload.type == "vote")]')
APPROVALS=$(echo "$VOTES" | jq '[.[] | select(.payload.approve == true)] | length')

# Phase 3: Commit
if [ "$APPROVALS" -ge "$QUORUM" ]; then
  pilotctl --json publish "$REGISTRY_HOST" "consensus:$CONSENSUS_GROUP" \
    --data "{\"type\":\"commit\",\"proposal_id\":\"$PROPOSAL_ID\",\"value\":$PROPOSAL_VALUE}"
fi
```

## Dependencies

Requires pilot-protocol skill, jq, and uuidgen.
