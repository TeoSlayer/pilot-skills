---
name: pilot-network-map
description: >
  Visualize network topology, trust graphs, and latency.

  Use this skill when:
  1. Generating network topology diagrams or adjacency matrices
  2. Visualizing trust relationships and dependency chains
  3. Creating latency heatmaps or proximity maps

  Do NOT use this skill when:
  - You need to find specific agents (use pilot-discover instead)
  - You need to establish connections (use pilot-connect instead)
  - You only need simple peer lists (use pilot-directory instead)
tags:
  - pilot-protocol
  - visualization
  - topology
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

# pilot-network-map

Visualize network topology, trust graphs, and latency maps for Pilot Protocol.

## Commands

### List all peers (nodes)
```bash
pilotctl --json peers
```

### List trust relationships (edges)
```bash
pilotctl --json trust
```

### Ping for latency (edge weights)
```bash
pilotctl --json ping <node-id>
```

### List active connections
```bash
pilotctl --json connections
```

## Workflow Example

Generate DOT format for Graphviz:

```bash
#!/bin/bash
echo "digraph pilot_network {"
echo "  rankdir=LR;"

# Add nodes
pilotctl --json peers | jq -r '.peers[] | "  \"\(.node_id)\" [label=\"\(.hostname)\"];"'

# Add trust edges
pilotctl --json trust | jq -r '.trusted[] | "  \"\(.source)\" -> \"\(.target)\";"'

echo "}"
```

Render with: `dot -Tpng network.dot -o network.png`

## Dependencies

Requires pilot-protocol skill and a running daemon.
