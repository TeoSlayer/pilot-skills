---
name: pilot-log-analytics-setup
description: >
  Deploy a log analytics system with 4 agents for collection, parsing, alerting, and visualization.

  Use this skill when:
  1. User wants to set up centralized log collection with parsing, anomaly detection, and dashboards
  2. User is configuring agents for log aggregation, error pattern analysis, or log-based alerting
  3. User asks about log pipelines, anomaly detection on logs, or log visualization across agents

  Do NOT use this skill when:
  - User wants to stream a single data feed (use pilot-stream-data instead)
  - User wants to set a one-off alert (use pilot-alert instead)
  - User only needs event filtering (use pilot-event-filter instead)
tags:
  - pilot-protocol
  - setup
  - log-analytics
  - observability
  - monitoring
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

# Log Analytics Setup

Deploy 4 agents: collector, parser, alerter, and dashboard.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| collector | `<prefix>-collector` | pilot-stream-data, pilot-archive, pilot-compress | Aggregates logs from servers, containers, apps; normalizes formats |
| parser | `<prefix>-parser` | pilot-event-filter, pilot-task-router, pilot-dataset | Extracts structured fields, parses stack traces, identifies patterns |
| alerter | `<prefix>-alerter` | pilot-alert, pilot-metrics, pilot-cron | Detects log spikes, error rate anomalies, fires alerts |
| dashboard | `<prefix>-dashboard` | pilot-webhook-bridge, pilot-slack-bridge, pilot-announce | Search, visualization, drill-down, and report generation |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For collector:
clawhub install pilot-stream-data pilot-archive pilot-compress
# For parser:
clawhub install pilot-event-filter pilot-task-router pilot-dataset
# For alerter:
clawhub install pilot-alert pilot-metrics pilot-cron
# For dashboard:
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-announce
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/log-analytics.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### collector
```json
{
  "setup": "log-analytics", "setup_name": "Log Analytics",
  "role": "collector", "role_name": "Log Collector",
  "hostname": "<prefix>-collector",
  "description": "Aggregates logs from servers, containers, and applications. Normalizes formats.",
  "skills": {"pilot-stream-data": "Ingest log streams from multiple sources in real time.", "pilot-archive": "Archive raw logs for retention and forensic analysis.", "pilot-compress": "Compress high-volume log batches before transmission."},
  "peers": [{"role": "parser", "hostname": "<prefix>-parser", "description": "Receives raw normalized logs"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-parser", "port": 1002, "topic": "raw-log", "description": "Raw normalized logs from all sources"}],
  "handshakes_needed": ["<prefix>-parser"]
}
```

### parser
```json
{
  "setup": "log-analytics", "setup_name": "Log Analytics",
  "role": "parser", "role_name": "Log Parser",
  "hostname": "<prefix>-parser",
  "description": "Extracts structured fields, parses stack traces, identifies error patterns.",
  "skills": {"pilot-event-filter": "Filter noise, deduplicate, and normalize log events.", "pilot-task-router": "Route logs to specialized parsers by source type and format.", "pilot-dataset": "Store extracted patterns and structured fields for search."},
  "peers": [{"role": "collector", "hostname": "<prefix>-collector", "description": "Sends raw logs"}, {"role": "alerter", "hostname": "<prefix>-alerter", "description": "Receives parsed events"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-collector", "port": 1002, "topic": "raw-log", "description": "Raw normalized logs from all sources"}, {"direction": "send", "peer": "<prefix>-alerter", "port": 1002, "topic": "parsed-event", "description": "Parsed events with structured fields and severity"}],
  "handshakes_needed": ["<prefix>-collector", "<prefix>-alerter"]
}
```

### alerter
```json
{
  "setup": "log-analytics", "setup_name": "Log Analytics",
  "role": "alerter", "role_name": "Anomaly Alerter",
  "hostname": "<prefix>-alerter",
  "description": "Detects log spikes, error rate anomalies, and novel error patterns. Fires alerts.",
  "skills": {"pilot-alert": "Fire alerts when error rates or log volumes breach thresholds.", "pilot-metrics": "Compute baseline rates, trend comparisons, and anomaly scores.", "pilot-cron": "Run scheduled anomaly scans over rolling time windows."},
  "peers": [{"role": "parser", "hostname": "<prefix>-parser", "description": "Sends parsed events"}, {"role": "dashboard", "hostname": "<prefix>-dashboard", "description": "Receives anomaly alerts"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-parser", "port": 1002, "topic": "parsed-event", "description": "Parsed events with structured fields"}, {"direction": "send", "peer": "<prefix>-dashboard", "port": 1002, "topic": "anomaly-alert", "description": "Anomaly alerts with context and baseline comparisons"}],
  "handshakes_needed": ["<prefix>-parser", "<prefix>-dashboard"]
}
```

### dashboard
```json
{
  "setup": "log-analytics", "setup_name": "Log Analytics",
  "role": "dashboard", "role_name": "Log Dashboard",
  "hostname": "<prefix>-dashboard",
  "description": "Provides search, visualization, and drill-down into log data. Generates reports.",
  "skills": {"pilot-webhook-bridge": "Forward reports to external dashboards and monitoring tools.", "pilot-slack-bridge": "Post log health summaries and critical alerts to Slack.", "pilot-announce": "Broadcast periodic log health reports to subscribers."},
  "peers": [{"role": "alerter", "hostname": "<prefix>-alerter", "description": "Sends anomaly alerts"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-alerter", "port": 1002, "topic": "anomaly-alert", "description": "Anomaly alerts with context and baselines"}, {"direction": "send", "peer": "external", "port": 443, "topic": "log-report", "description": "Log reports to dashboards and Slack channels"}],
  "handshakes_needed": ["<prefix>-alerter"]
}
```

## Data Flows

- `collector -> parser` : raw-log events from all sources (port 1002)
- `parser -> alerter` : parsed-event with structured fields and severity (port 1002)
- `alerter -> dashboard` : anomaly-alert with context and baselines (port 1002)
- `dashboard -> external` : log-report via webhooks and Slack (port 443)

## Handshakes

```bash
# collector <-> parser:
pilotctl --json handshake <prefix>-parser "setup: log-analytics"
pilotctl --json handshake <prefix>-collector "setup: log-analytics"
# parser <-> alerter:
pilotctl --json handshake <prefix>-alerter "setup: log-analytics"
pilotctl --json handshake <prefix>-parser "setup: log-analytics"
# alerter <-> dashboard:
pilotctl --json handshake <prefix>-dashboard "setup: log-analytics"
pilotctl --json handshake <prefix>-alerter "setup: log-analytics"
```

## Workflow Example

```bash
# On collector -- publish raw log:
pilotctl --json publish <prefix>-parser raw-log '{"source":"nginx-prod-01","level":"error","message":"upstream timed out"}'
# On parser -- publish parsed event:
pilotctl --json publish <prefix>-alerter parsed-event '{"pattern_id":"NGINX-TIMEOUT-001","level":"error","occurrences_1h":47}'
# On alerter -- publish anomaly alert:
pilotctl --json publish <prefix>-dashboard anomaly-alert '{"alert_id":"ALR-7829","type":"error_spike","severity":"critical","current_rate":47,"baseline_rate":3}'
# On dashboard -- publish log report:
pilotctl --json publish <prefix>-dashboard log-report '{"period":"2026-04-09T15:00Z/PT1H","errors":1290,"anomalies_detected":2}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
