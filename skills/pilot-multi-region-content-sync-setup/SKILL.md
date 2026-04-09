---
name: pilot-multi-region-content-sync-setup
description: >
  Deploy a multi-region content distribution system with 4 agents.

  Use this skill when:
  1. User wants to sync content across geographic regions
  2. User is configuring an origin or edge node for content distribution
  3. User asks about CDN-like content replication between agents

  Do NOT use this skill when:
  - User wants to sync a single file (use pilot-sync instead)
  - User wants a one-shot file transfer (use pilot-share instead)
tags:
  - pilot-protocol
  - setup
  - content-sync
  - multi-region
license: AGPL-3.0
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - clawhub
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Multi-Region Content Sync Setup

Deploy 4 agents: 1 origin + 3 regional edge nodes for content distribution.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| origin | `<prefix>-origin` | pilot-sync, pilot-share, pilot-broadcast, pilot-heartbeat-monitor | Source of truth, broadcasts updates |
| edge-us | `<prefix>-edge-us` | pilot-sync, pilot-share, pilot-health, pilot-heartbeat-monitor | US regional edge |
| edge-eu | `<prefix>-edge-eu` | pilot-sync, pilot-share, pilot-health, pilot-heartbeat-monitor | EU regional edge |
| edge-asia | `<prefix>-edge-asia` | pilot-sync, pilot-share, pilot-health, pilot-heartbeat-monitor | Asia regional edge |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For origin:
clawhub install pilot-sync pilot-share pilot-broadcast pilot-heartbeat-monitor
# For any edge node:
clawhub install pilot-sync pilot-share pilot-health pilot-heartbeat-monitor
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the role-specific JSON manifest to `~/.pilot/setups/multi-region-content-sync.json`.

**Step 5:** Tell the user to initiate handshakes.

## Manifest Templates Per Role

### origin
```json
{
  "setup": "multi-region-content-sync", "role": "origin", "role_name": "Content Origin",
  "hostname": "<prefix>-origin",
  "description": "Source of truth for all content. Broadcasts updates to all edge nodes.",
  "skills": {
    "pilot-sync": "Push content changes to all edge nodes.",
    "pilot-share": "Transfer new content files to edges.",
    "pilot-broadcast": "Broadcast content-update events to all edges simultaneously.",
    "pilot-heartbeat-monitor": "Track heartbeats from all edges, alert when a region goes dark."
  },
  "peers": [
    { "role": "edge-us", "hostname": "<prefix>-edge-us", "description": "US regional edge node" },
    { "role": "edge-eu", "hostname": "<prefix>-edge-eu", "description": "EU regional edge node" },
    { "role": "edge-asia", "hostname": "<prefix>-edge-asia", "description": "Asia regional edge node" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-edge-us", "port": 1001, "topic": "content-update", "description": "Content updates" },
    { "direction": "send", "peer": "<prefix>-edge-eu", "port": 1001, "topic": "content-update", "description": "Content updates" },
    { "direction": "send", "peer": "<prefix>-edge-asia", "port": 1001, "topic": "content-update", "description": "Content updates" },
    { "direction": "receive", "peer": "<prefix>-edge-us", "port": 1002, "topic": "heartbeat", "description": "Health heartbeats" },
    { "direction": "receive", "peer": "<prefix>-edge-eu", "port": 1002, "topic": "heartbeat", "description": "Health heartbeats" },
    { "direction": "receive", "peer": "<prefix>-edge-asia", "port": 1002, "topic": "heartbeat", "description": "Health heartbeats" }
  ],
  "handshakes_needed": ["<prefix>-edge-us", "<prefix>-edge-eu", "<prefix>-edge-asia"]
}
```

### edge-us / edge-eu / edge-asia
```json
{
  "setup": "multi-region-content-sync", "role": "edge-<region>", "role_name": "<Region> Edge Node",
  "hostname": "<prefix>-edge-<region>",
  "description": "Serves content for the <region> region. Syncs from origin and reports health.",
  "skills": {
    "pilot-sync": "Pull content updates from origin.",
    "pilot-share": "Receive content files from origin.",
    "pilot-health": "Monitor local health and sync status.",
    "pilot-heartbeat-monitor": "Send periodic heartbeats to origin."
  },
  "peers": [{ "role": "origin", "hostname": "<prefix>-origin", "description": "Content source — receives updates from here" }],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-origin", "port": 1001, "topic": "content-update", "description": "Content updates" },
    { "direction": "send", "peer": "<prefix>-origin", "port": 1002, "topic": "heartbeat", "description": "Health heartbeats" }
  ],
  "handshakes_needed": ["<prefix>-origin"]
}
```

## Data Flows

- `origin → edge-*` : content updates (port 1001)
- `edge-* → origin` : heartbeat and sync confirmation (port 1002)

## Workflow Example

```bash
# On origin — broadcast content:
pilotctl --json send-file <prefix>-edge-us ./content/index.html
pilotctl --json publish <prefix>-edge-us content-update '{"file":"index.html","version":42}'
# On edge — confirm and heartbeat:
pilotctl --json publish <prefix>-origin sync-complete '{"region":"us","version":42}'
pilotctl --json publish <prefix>-origin heartbeat '{"region":"us","status":"healthy"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
