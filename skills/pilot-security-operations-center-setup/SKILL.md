---
name: pilot-security-operations-center-setup
description: >
  Deploy a security operations center pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up a SOC or security monitoring pipeline
  2. User is configuring a log collector, threat analyzer, enforcer, or dashboard agent
  3. User asks about threat detection, blocklisting, or security event correlation

  Do NOT use this skill when:
  - User wants a single security check (use pilot-watchdog instead)
  - User wants to blocklist one agent (use pilot-blocklist instead)
tags:
  - pilot-protocol
  - setup
  - security
  - soc
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

# Security Operations Center Setup

Deploy 4 agents: collector, analyzer, enforcer, and dashboard.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| collector | `<prefix>-collector` | pilot-event-log, pilot-audit-log, pilot-stream-data, pilot-cron | Aggregates security events |
| analyzer | `<prefix>-analyzer` | pilot-event-filter, pilot-event-replay, pilot-alert, pilot-priority-queue | Detects and classifies threats |
| enforcer | `<prefix>-enforcer` | pilot-blocklist, pilot-quarantine, pilot-webhook-bridge, pilot-audit-log | Blocks threats, quarantines nodes |
| dashboard | `<prefix>-dashboard` | pilot-metrics, pilot-slack-bridge, pilot-network-map, pilot-mesh-status | Visualizes security posture |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# collector:
clawhub install pilot-event-log pilot-audit-log pilot-stream-data pilot-cron
# analyzer:
clawhub install pilot-event-filter pilot-event-replay pilot-alert pilot-priority-queue
# enforcer:
clawhub install pilot-blocklist pilot-quarantine pilot-webhook-bridge pilot-audit-log
# dashboard:
clawhub install pilot-metrics pilot-slack-bridge pilot-network-map pilot-mesh-status
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/security-operations-center.json`.

**Step 4:** Handshake with adjacent agents.

## Manifest Templates Per Role

### collector
```json
{
  "setup": "security-operations-center", "role": "collector", "role_name": "Log Collector",
  "hostname": "<prefix>-collector",
  "skills": {
    "pilot-event-log": "Aggregate security events from all nodes.",
    "pilot-audit-log": "Maintain tamper-evident event log.",
    "pilot-stream-data": "Stream events to analyzer in real time.",
    "pilot-cron": "Schedule periodic log sweeps."
  },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-analyzer", "port": 1002, "topic": "security-event", "description": "Raw security events" }],
  "handshakes_needed": ["<prefix>-analyzer"]
}
```

### analyzer
```json
{
  "setup": "security-operations-center", "role": "analyzer", "role_name": "Threat Analyzer",
  "hostname": "<prefix>-analyzer",
  "skills": {
    "pilot-event-filter": "Filter and correlate events, detect patterns.",
    "pilot-event-replay": "Replay past events for forensic investigation.",
    "pilot-alert": "Emit classified threat alerts.",
    "pilot-priority-queue": "Prioritize threats by severity."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-collector", "port": 1002, "topic": "security-event", "description": "Raw events" },
    { "direction": "send", "peer": "<prefix>-enforcer", "port": 1002, "topic": "threat-verdict", "description": "Threat verdicts" },
    { "direction": "send", "peer": "<prefix>-dashboard", "port": 1002, "topic": "threat-alert", "description": "Classified threats" }
  ],
  "handshakes_needed": ["<prefix>-collector", "<prefix>-enforcer", "<prefix>-dashboard"]
}
```

### enforcer
```json
{
  "setup": "security-operations-center", "role": "enforcer", "role_name": "Threat Enforcer",
  "hostname": "<prefix>-enforcer",
  "skills": {
    "pilot-blocklist": "Add malicious IPs/agents to deny list.",
    "pilot-quarantine": "Isolate compromised agents.",
    "pilot-webhook-bridge": "Trigger incident webhooks.",
    "pilot-audit-log": "Log all enforcement actions."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-analyzer", "port": 1002, "topic": "threat-verdict", "description": "Threat verdicts" },
    { "direction": "send", "peer": "<prefix>-dashboard", "port": 1002, "topic": "enforcement-action", "description": "Actions taken" }
  ],
  "handshakes_needed": ["<prefix>-analyzer", "<prefix>-dashboard"]
}
```

### dashboard
```json
{
  "setup": "security-operations-center", "role": "dashboard", "role_name": "SOC Dashboard",
  "hostname": "<prefix>-dashboard",
  "skills": {
    "pilot-metrics": "Display threat counts, response times.",
    "pilot-slack-bridge": "Send security summaries to Slack.",
    "pilot-network-map": "Visualize network topology and threats.",
    "pilot-mesh-status": "Show peer connectivity and encryption status."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-analyzer", "port": 1002, "topic": "threat-alert", "description": "Classified threats" },
    { "direction": "receive", "peer": "<prefix>-enforcer", "port": 1002, "topic": "enforcement-action", "description": "Actions taken" }
  ],
  "handshakes_needed": ["<prefix>-analyzer", "<prefix>-enforcer"]
}
```

## Data Flows

- `collector → analyzer` : raw security events (port 1002)
- `analyzer → enforcer` : threat verdicts (port 1002)
- `analyzer → dashboard` : classified threats (port 1002)
- `enforcer → dashboard` : enforcement actions (port 1002)

## Workflow Example

```bash
# On collector:
pilotctl --json publish <prefix>-analyzer security-event '{"type":"port_scan","source":"203.0.113.42","ports":1024}'
# On analyzer:
pilotctl --json publish <prefix>-enforcer threat-verdict '{"source":"203.0.113.42","severity":"high","action":"block"}'
# On enforcer:
pilotctl --json publish <prefix>-dashboard enforcement-action '{"source":"203.0.113.42","action":"blocked"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
