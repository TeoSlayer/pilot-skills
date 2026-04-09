---
name: pilot-agent-marketplace-setup
description: >
  Deploy a decentralized agent marketplace with 4 agents.

  Use this skill when:
  1. User wants to set up an agent capability marketplace
  2. User is configuring a directory, matchmaker, escrow, or gateway agent
  3. User asks about capability discovery, auctions, or escrow settlement

  Do NOT use this skill when:
  - User wants to discover a single agent (use pilot-discover instead)
  - User wants to run a single auction (use pilot-auction instead)
tags:
  - pilot-protocol
  - setup
  - marketplace
  - discovery
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

# Agent Marketplace Setup

Deploy 4 agents: directory, matchmaker, escrow, and gateway.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| directory | `<prefix>-directory` | pilot-directory, pilot-announce-capabilities, pilot-discover, pilot-reputation | Capability registry |
| matchmaker | `<prefix>-matchmaker` | pilot-matchmaker, pilot-auction, pilot-priority-queue, pilot-audit-log | Matches requests to providers |
| escrow | `<prefix>-escrow` | pilot-escrow, pilot-receipt, pilot-audit-log, pilot-webhook-bridge | Transaction settlement |
| gateway | `<prefix>-gateway` | pilot-api-gateway, pilot-health, pilot-load-balancer, pilot-metrics | Public API entry point |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# directory:
clawhub install pilot-directory pilot-announce-capabilities pilot-discover pilot-reputation
# matchmaker:
clawhub install pilot-matchmaker pilot-auction pilot-priority-queue pilot-audit-log
# escrow:
clawhub install pilot-escrow pilot-receipt pilot-audit-log pilot-webhook-bridge
# gateway:
clawhub install pilot-api-gateway pilot-health pilot-load-balancer pilot-metrics
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/agent-marketplace.json`.

**Step 4:** Handshake: gateway↔matchmaker↔directory, matchmaker↔escrow↔directory, gateway↔directory.

## Manifest Templates Per Role

### directory
```json
{
  "setup": "agent-marketplace", "role": "directory", "role_name": "Capability Directory",
  "hostname": "<prefix>-directory",
  "skills": {
    "pilot-directory": "Maintain registry of agent capabilities.",
    "pilot-announce-capabilities": "Accept capability announcements.",
    "pilot-discover": "Serve capability queries from matchmaker.",
    "pilot-reputation": "Track reputation scores from completed transactions."
  },
  "handshakes_needed": ["<prefix>-matchmaker", "<prefix>-escrow", "<prefix>-gateway"]
}
```

### matchmaker
```json
{
  "setup": "agent-marketplace", "role": "matchmaker", "role_name": "Request Matchmaker",
  "hostname": "<prefix>-matchmaker",
  "skills": {
    "pilot-matchmaker": "Match requests with capable providers.",
    "pilot-auction": "Run competitive auctions when multiple providers match.",
    "pilot-priority-queue": "Queue requests by urgency.",
    "pilot-audit-log": "Log all matching decisions."
  },
  "handshakes_needed": ["<prefix>-directory", "<prefix>-escrow", "<prefix>-gateway"]
}
```

### escrow
```json
{
  "setup": "agent-marketplace", "role": "escrow", "role_name": "Transaction Escrow",
  "hostname": "<prefix>-escrow",
  "skills": {
    "pilot-escrow": "Hold payment until task completion.",
    "pilot-receipt": "Issue settlement receipts.",
    "pilot-audit-log": "Log all transactions.",
    "pilot-webhook-bridge": "Notify external systems on settlement."
  },
  "handshakes_needed": ["<prefix>-matchmaker", "<prefix>-directory"]
}
```

### gateway
```json
{
  "setup": "agent-marketplace", "role": "gateway", "role_name": "Marketplace Gateway",
  "hostname": "<prefix>-gateway",
  "skills": {
    "pilot-api-gateway": "Accept external task requests.",
    "pilot-health": "Monitor marketplace health.",
    "pilot-load-balancer": "Balance across matchmaker replicas.",
    "pilot-metrics": "Track marketplace throughput and latency."
  },
  "handshakes_needed": ["<prefix>-directory", "<prefix>-matchmaker"]
}
```

## Data Flows

- `gateway → matchmaker` : incoming task requests (port 1002)
- `matchmaker → directory` : capability queries (port 1002)
- `matchmaker → escrow` : escrow initiation (port 1002)
- `escrow → directory` : reputation updates (port 1002)
- `gateway → directory` : discovery queries (port 1002)

## Workflow Example

```bash
# On gateway:
pilotctl --json publish <prefix>-matchmaker capability-request '{"need":"image-classification","budget":50}'
# On matchmaker:
pilotctl --json publish <prefix>-directory discover-capability '{"capability":"image-classification"}'
# On matchmaker:
pilotctl --json publish <prefix>-escrow escrow-create '{"provider":"img-classifier","amount":30}'
# On escrow:
pilotctl --json publish <prefix>-directory reputation-update '{"agent":"img-classifier","rating":5}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
