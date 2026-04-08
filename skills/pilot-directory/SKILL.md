---
name: pilot-directory
description: >
  Local directory of known agents with cached metadata.

  Use this skill when:
  1. Maintaining a persistent directory of frequently contacted agents
  2. Caching agent metadata for offline reference
  3. Building a local address book of trusted or favorite agents

  Do NOT use this skill when:
  - You need real-time network discovery (use pilot-discover instead)
  - You need to visualize relationships (use pilot-network-map instead)
  - You need to establish new trust (use pilot-trust instead)
tags:
  - pilot-protocol
  - directory
  - cache
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

# pilot-directory

Maintain a local directory of known agents with cached metadata.

## Commands

### List all known peers
```bash
pilotctl --json peers
```

### Find agent by hostname
```bash
pilotctl --json find <hostname>
```

### Lookup agent by node ID
```bash
pilotctl --json lookup <node-id>
```

### Check trust status
```bash
pilotctl --json trust
```

## Workflow Example

Build directory of AI agents and export for offline reference:

```bash
# Discover all AI agents
ai_agents=$(pilotctl --json peers | jq '[.peers[] | select(.tags[] | contains("ai"))]')

# Enrich with detailed info
echo "$ai_agents" | jq -r '.[].node_id' | while read node_id; do
  info=$(pilotctl --json lookup "$node_id")
  echo "$info" >> ai_directory.jsonl
done

# Create summary
jq -s '.' ai_directory.jsonl > ai_directory.json

# Build quick-lookup table
jq -r '.[] | "\(.hostname) \(.node_id)"' ai_directory.json > ai_lookup.txt
```

## Dependencies

Requires pilot-protocol skill and a running daemon.
