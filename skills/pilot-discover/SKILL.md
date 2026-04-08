---
name: pilot-discover
description: >
  Advanced agent discovery by tags, polo score, and status.

  Use this skill when:
  1. Finding agents by specific capabilities (tags like "ai", "storage", "compute")
  2. Searching for high-quality peers based on polo score
  3. Looking up detailed agent information and metadata

  Do NOT use this skill when:
  - You need to establish trust (use pilot-trust instead)
  - You need to connect to a known agent (use pilot-connect instead)
  - You need to visualize the network (use pilot-network-map instead)
tags:
  - pilot-protocol
  - discovery
  - search
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

# pilot-discover

Advanced agent discovery within the Pilot Protocol overlay network.

## Commands

### Search by Tags
```bash
pilotctl --json peers --search "tag1 tag2 tag3"
```

### Find by Hostname
```bash
pilotctl --json find <hostname>
```

### Lookup by Node ID
```bash
pilotctl --json lookup <node-id>
```

### Get Own Info
```bash
pilotctl --json info
```

### List All Peers
```bash
pilotctl --json peers
```

## Workflow Example

```bash
#!/bin/bash
# Find AI agents with GPU capability and high polo score

result=$(pilotctl --json peers --search "ai gpu")
high_quality=$(echo "$result" | jq '[.peers[] | select(.polo_score >= 0.5)]')
top_agent=$(echo "$high_quality" | jq -r '.[0].node_id')

pilotctl --json lookup "$top_agent"
pilotctl --json ping "$top_agent"
```

## Tag Conventions

- Compute: `gpu`, `cpu`, `tpu`, `compute`
- Storage: `storage`, `ipfs`, `s3`, `cache`
- AI: `ai`, `llm`, `inference`, `training`, `embedding`
- Services: `relay`, `gateway`, `dns`, `http`

## Polo Score

- 0.8-1.0: Highly reliable, long uptime
- 0.5-0.8: Good quality, stable
- 0.3-0.5: Moderate quality, newer
- 0.0-0.3: Low quality, unreliable

## Dependencies

Requires pilot-protocol core skill and running daemon with registry access.
