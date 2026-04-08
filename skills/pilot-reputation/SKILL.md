---
name: pilot-reputation
description: >
  Advanced reputation analytics and trend visualization for Pilot Protocol agents.

  Use this skill when:
  1. You need to track polo score trends over time for agents
  2. You want to analyze reputation patterns across your network
  3. You need to make trust decisions based on reputation history

  Do NOT use this skill when:
  - You only need current polo scores (use pilotctl lookup)
  - You need real-time monitoring (use pilot-watchdog)
  - You're doing one-time verification (use pilot-verify)
tags:
  - pilot-protocol
  - trust-security
  - analytics
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

# Pilot Reputation

Advanced reputation analytics for Pilot Protocol with trend tracking and scoring algorithms.

## Commands

### Record Snapshot
```bash
cat > ~/.pilot/reputation/data/snapshot-$(date +%s).json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "local_agent": $(pilotctl --json info | jq '{hostname, address, polo_score}'),
  "peers": $(pilotctl --json peers)
}
EOF
```

### Query History
```bash
find ~/.pilot/reputation/data -name "snapshot-*.json" -mtime -7 | sort | \
while read SNAPSHOT; do
  jq -r --arg agent "$AGENT" '.peers[] | select(.hostname == $agent) | "\(.timestamp): \(.polo_score)"' "$SNAPSHOT"
done
```

### Calculate Trend
```bash
SCORES=$(find ~/.pilot/reputation/data -name "snapshot-*.json" -mtime -7 | sort | \
  while read SNAPSHOT; do
    jq -r --arg agent "$AGENT" '.peers[] | select(.hostname == $agent) | .polo_score' "$SNAPSHOT"
  done)

FIRST=$(echo "$SCORES" | head -1)
LAST=$(echo "$SCORES" | tail -1)
echo "Change: $((LAST - FIRST))"
```

## Workflow Example

```bash
#!/bin/bash
# Continuous reputation tracking

REPO_DIR=~/.pilot/reputation
mkdir -p "$REPO_DIR/data"

while true; do
  cat > "$REPO_DIR/data/snapshot-$(date +%s).json" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","peers":$(pilotctl --json peers)}
EOF
  sleep 300
done
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and bc.
