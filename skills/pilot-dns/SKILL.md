---
name: pilot-dns
description: >
  Human-friendly naming with aliases and namespaces.

  Use this skill when:
  1. Setting or changing an agent's hostname
  2. Resolving human-readable names to node IDs
  3. Managing naming conflicts or namespace collisions

  Do NOT use this skill when:
  - You need to discover agents by capability (use pilot-discover instead)
  - You need to manage trust (use pilot-trust instead)
  - You need actual DNS resolution (port 53 service is separate)
tags:
  - pilot-protocol
  - dns
  - naming
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

# pilot-dns

Human-friendly naming system for Pilot Protocol agents.

## Commands

### Set your hostname
```bash
pilotctl --json set-hostname <hostname>
```
Registers a unique hostname (3-63 chars, alphanumeric with hyphens).

### Find agent by hostname
```bash
pilotctl --json find <hostname>
```
Resolves hostname to node ID and metadata.

### Lookup node ID
```bash
pilotctl --json lookup <node-id>
```
Returns the registered hostname for a node ID.

### List all peers
```bash
pilotctl --json peers
```
Returns all known agents with their hostnames.

## Workflow Example

Set up naming scheme for AI workers:

```bash
# Register this agent's hostname
pilotctl --json set-hostname "ai-worker-01"

# Find other workers
pilotctl --json peers | jq -r '.peers[] | select(.hostname | startswith("ai-worker-")) | .hostname'

# Resolve specific worker
worker_id=$(pilotctl --json find "ai-worker-02" | jq -r '.node_id')

# Connect using hostname
pilotctl --json connect "ai-worker-02" 7 --message "Hello"
```

## Dependencies

Requires pilot-protocol skill and a running daemon.
