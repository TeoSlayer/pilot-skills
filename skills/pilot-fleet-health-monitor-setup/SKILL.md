---
name: pilot-fleet-health-monitor-setup
description: >
  Deploy a fleet health monitoring system with 3 agents.

  Use this skill when:
  1. User wants to set up fleet or server health monitoring
  2. User is configuring an agent as part of a health monitoring setup
  3. User asks about monitoring, alerting, or metrics collection across agents

  Do NOT use this skill when:
  - User wants a single health check (use pilot-health instead)
  - User wants to send a one-off alert (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - monitoring
  - fleet
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

# Fleet Health Monitor Setup

Deploy 3 agents that monitor server health and aggregate alerts.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| web-monitor | `<prefix>-web-monitor` | pilot-health, pilot-alert, pilot-metrics | Monitors web servers, publishes health alerts |
| db-monitor | `<prefix>-db-monitor` | pilot-health, pilot-alert, pilot-metrics | Monitors databases, publishes health alerts |
| alert-hub | `<prefix>-alert-hub` | pilot-webhook-bridge, pilot-alert, pilot-event-filter, pilot-slack-bridge | Aggregates alerts, forwards to humans |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For web-monitor or db-monitor:
clawhub install pilot-health pilot-alert pilot-metrics

# For alert-hub:
clawhub install pilot-webhook-bridge pilot-alert pilot-event-filter pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/fleet-health-monitor.json << 'MANIFEST'
{
  "setup": "fleet-health-monitor",
  "setup_name": "Fleet Health Monitor",
  "role": "<ROLE_ID>",
  "role_name": "<ROLE_NAME>",
  "hostname": "<prefix>-<role>",
  "description": "<ROLE_DESCRIPTION>",
  "skills": { "<skill>": "<contextual description>" },
  "peers": [ { "role": "...", "hostname": "...", "description": "..." } ],
  "data_flows": [ { "direction": "send|receive", "peer": "...", "port": 1002, "topic": "...", "description": "..." } ],
  "handshakes_needed": [ "<peer-hostname>" ]
}
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### web-monitor
```json
{
  "setup": "fleet-health-monitor",
  "setup_name": "Fleet Health Monitor",
  "role": "web-monitor",
  "role_name": "Web Server Monitor",
  "hostname": "<prefix>-web-monitor",
  "description": "Watches nginx/app health, CPU, memory, and response times. Emits alert events when thresholds are breached.",
  "skills": {
    "pilot-health": "Check nginx, app endpoints, SSL certs. Run on schedule or on-demand.",
    "pilot-alert": "When health checks fail, publish alert to <prefix>-alert-hub on topic health-alert.",
    "pilot-metrics": "Collect CPU, memory, disk, and response time. Format as JSON event payloads."
  },
  "peers": [
    { "role": "db-monitor", "hostname": "<prefix>-db-monitor", "description": "Fellow monitor — does not communicate directly" },
    { "role": "alert-hub", "hostname": "<prefix>-alert-hub", "description": "Central alert aggregator — receives health-alert events" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-alert-hub", "port": 1002, "topic": "health-alert", "description": "Health check failures and metric anomalies" }
  ],
  "handshakes_needed": ["<prefix>-alert-hub"]
}
```

### db-monitor
```json
{
  "setup": "fleet-health-monitor",
  "setup_name": "Fleet Health Monitor",
  "role": "db-monitor",
  "role_name": "Database Monitor",
  "hostname": "<prefix>-db-monitor",
  "description": "Monitors database connections, query latency, replication lag, and disk usage. Emits alerts on anomalies.",
  "skills": {
    "pilot-health": "Check PostgreSQL/MySQL connections, replication lag, disk usage.",
    "pilot-alert": "When DB health fails, publish alert to <prefix>-alert-hub on topic health-alert.",
    "pilot-metrics": "Collect query latency, connection pool stats, table sizes."
  },
  "peers": [
    { "role": "web-monitor", "hostname": "<prefix>-web-monitor", "description": "Fellow monitor — does not communicate directly" },
    { "role": "alert-hub", "hostname": "<prefix>-alert-hub", "description": "Central alert aggregator — receives health-alert events" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-alert-hub", "port": 1002, "topic": "health-alert", "description": "Database alerts and replication warnings" }
  ],
  "handshakes_needed": ["<prefix>-alert-hub"]
}
```

### alert-hub
```json
{
  "setup": "fleet-health-monitor",
  "setup_name": "Fleet Health Monitor",
  "role": "alert-hub",
  "role_name": "Alert Aggregator",
  "hostname": "<prefix>-alert-hub",
  "description": "Receives alerts from all monitors, filters duplicates and noise, then forwards critical alerts to Slack and PagerDuty via webhooks.",
  "skills": {
    "pilot-webhook-bridge": "Forward critical alerts to Slack and PagerDuty via webhook URLs.",
    "pilot-alert": "Subscribe to health-alert from all monitors. Aggregate and deduplicate.",
    "pilot-event-filter": "Filter noise and low-severity alerts before forwarding.",
    "pilot-slack-bridge": "Post formatted alert summaries to Slack channels."
  },
  "peers": [
    { "role": "web-monitor", "hostname": "<prefix>-web-monitor", "description": "Sends health alerts from web servers" },
    { "role": "db-monitor", "hostname": "<prefix>-db-monitor", "description": "Sends health alerts from databases" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-web-monitor", "port": 1002, "topic": "health-alert", "description": "Health check failures and metric anomalies" },
    { "direction": "receive", "peer": "<prefix>-db-monitor", "port": 1002, "topic": "health-alert", "description": "Database alerts and replication warnings" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "slack-forward", "description": "Filtered alerts to Slack and PagerDuty" }
  ],
  "handshakes_needed": ["<prefix>-web-monitor", "<prefix>-db-monitor"]
}
```

## Data Flows

- `web-monitor → alert-hub` : health-alert events (port 1002)
- `db-monitor → alert-hub` : health-alert events (port 1002)
- `alert-hub → humans` : forwarded alerts via webhook/announce

## Handshakes

```bash
# web-monitor and db-monitor handshake with alert-hub:
pilotctl --json handshake <prefix>-alert-hub "setup: fleet-health-monitor"

# alert-hub handshakes with both monitors:
pilotctl --json handshake <prefix>-web-monitor "setup: fleet-health-monitor"
pilotctl --json handshake <prefix>-db-monitor "setup: fleet-health-monitor"
```

## Workflow Example

```bash
# On alert-hub — subscribe to health events:
pilotctl --json subscribe <prefix>-web-monitor health-alert
pilotctl --json subscribe <prefix>-db-monitor health-alert

# On web-monitor — publish a health alert:
pilotctl --json publish <prefix>-alert-hub health-alert '{"host":"web-01","status":"critical","cpu":95,"mem":88}'

# On db-monitor — publish a database alert:
pilotctl --json publish <prefix>-alert-hub health-alert '{"host":"db-01","status":"warning","disk_pct":88,"repl_lag_ms":450}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
