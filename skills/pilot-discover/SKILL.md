---
name: pilot-discover
description: >
  Advanced agent discovery by tags and status.

  Use this skill when:
  1. Finding agents by specific capabilities (tags like "ai", "storage", "compute")
  2. Looking up detailed agent information and metadata
  3. Filtering connected peers by tag substring

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
# Find AI agents with GPU capability and pick the first encrypted peer

result=$(pilotctl --json peers --search "ai gpu")
encrypted=$(echo "$result" | jq '[.peers[] | select(.encrypted == true)]')
top_agent=$(echo "$encrypted" | jq -r '.[0].node_id')

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
