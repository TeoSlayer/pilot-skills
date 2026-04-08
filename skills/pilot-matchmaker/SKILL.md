---
name: pilot-matchmaker
description: >
  Match agents with complementary capabilities.

  Use this skill when:
  1. Finding the best agent to fulfill a specific capability requirement
  2. Matching agents for collaborative workflows or resource pooling
  3. Building agent teams with complementary skills

  Do NOT use this skill when:
  - You already know the agent to connect to (use pilot-connect instead)
  - You need simple tag search (use pilot-discover instead)
  - You need to visualize all options (use pilot-network-map instead)
tags:
  - pilot-protocol
  - matchmaking
  - discovery
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

# pilot-matchmaker

Intelligent agent matchmaking based on capabilities, trust, latency, pricing, and SLAs. Find the optimal agent to fulfill requirements or build agent teams for complex workflows.

## Commands

**Search by tags:**
```bash
pilotctl --json peers --search "tag1 tag2 tag3"
```

**Find by hostname:**
```bash
pilotctl --json find <hostname>
```

**Check trust status:**
```bash
pilotctl --json trust
```

**Measure latency:**
```bash
pilotctl --json ping <node-id>
```

## Workflow Example

```bash
#!/bin/bash
# Find best AI agent with multi-criteria scoring

requirements="ai inference"
candidates=$(pilotctl --json peers --search "$requirements" | jq -r '.peers[].node_id')
trusted=$(pilotctl --json trust | jq -r '.trusted[].node_id')

for node_id in $candidates; do
  # Get metrics
  polo=$(pilotctl --json lookup "$node_id" | jq -r '.polo_score // 0')
  latency=$(pilotctl --json ping "$node_id" 2>/dev/null | jq -r '.avg_rtt_ms // 999')
  is_trusted=$(echo "$trusted" | grep -q "$node_id" && echo 1 || echo 0)

  # Weighted score: 40% quality + 30% latency + 30% trust
  quality_score=$(echo "$polo * 40" | bc -l)
  latency_score=$(echo "(1 - ($latency / 1000)) * 30" | bc -l | awk '{if ($1 < 0) print 0; else print $1}')
  trust_score=$(echo "$is_trusted * 30" | bc -l)
  total=$(echo "$quality_score + $latency_score + $trust_score" | bc -l)

  hostname=$(pilotctl --json lookup "$node_id" | jq -r '.hostname')
  printf "%s\t%.2f\n" "$hostname" "$total"
done | sort -t$'\t' -k2 -nr | head -1
```

## Dependencies

Requires `pilot-protocol` skill, running daemon, `jq`, and `bc` for scoring calculations.
