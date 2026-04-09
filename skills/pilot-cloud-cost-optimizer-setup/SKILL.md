---
name: pilot-cloud-cost-optimizer-setup
description: >
  Deploy a cloud cost optimization pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up a FinOps or cloud cost optimization pipeline
  2. User is configuring a scanner, analyzer, optimizer, or reporter agent for cloud costs
  3. User asks about automated cloud spend analysis and optimization workflows

  Do NOT use this skill when:
  - User wants to monitor generic application metrics (use pilot-metrics instead)
  - User wants to send a single alert or notification (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - finops
  - cloud
  - cost-optimization
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

# Cloud Cost Optimizer Setup

Deploy 4 agents that scan, analyze, optimize, and report on cloud spending with zero central server.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| scanner | `<prefix>-scanner` | pilot-cron, pilot-stream-data, pilot-metrics, pilot-health | Scans cloud resources, collects billing and utilization data |
| analyzer | `<prefix>-analyzer` | pilot-event-filter, pilot-alert, pilot-metrics | Identifies waste, rightsizing, and spend anomalies |
| optimizer | `<prefix>-optimizer` | pilot-task-router, pilot-audit-log, pilot-receipt | Executes approved optimizations, logs actions |
| reporter | `<prefix>-reporter` | pilot-webhook-bridge, pilot-slack-bridge, pilot-announce | Generates cost reports, sends to Slack/email |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For scanner:
clawhub install pilot-cron pilot-stream-data pilot-metrics pilot-health
# For analyzer:
clawhub install pilot-event-filter pilot-alert pilot-metrics
# For optimizer:
clawhub install pilot-task-router pilot-audit-log pilot-receipt
# For reporter:
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-announce
```

**Step 3:** Set the hostname and write the manifest:
```bash
pilotctl --json set-hostname <prefix>-<role>
mkdir -p ~/.pilot/setups
```
Then write the role-specific JSON manifest to `~/.pilot/setups/cloud-cost-optimizer.json`.

**Step 4:** Tell the user to initiate handshakes with adjacent agents.

## Manifest Templates Per Role

### scanner
```json
{
  "setup": "cloud-cost-optimizer", "role": "scanner", "role_name": "Resource Scanner",
  "hostname": "<prefix>-scanner",
  "skills": { "pilot-cron": "Schedule periodic scans.", "pilot-stream-data": "Stream utilization to analyzer.", "pilot-metrics": "Normalize CPU/memory/network metrics.", "pilot-health": "Report scanner readiness." },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-analyzer", "port": 1002, "topic": "resource-scan" }],
  "handshakes_needed": ["<prefix>-analyzer"]
}
```

### analyzer
```json
{
  "setup": "cloud-cost-optimizer", "role": "analyzer", "role_name": "Cost Analyzer",
  "hostname": "<prefix>-analyzer",
  "skills": { "pilot-event-filter": "Filter by cost threshold.", "pilot-alert": "Alert on spend spikes.", "pilot-metrics": "Track cost trends." },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-scanner", "port": 1002, "topic": "resource-scan" },
    { "direction": "send", "peer": "<prefix>-optimizer", "port": 1002, "topic": "cost-recommendation" },
    { "direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "cost-anomaly" }
  ],
  "handshakes_needed": ["<prefix>-scanner", "<prefix>-optimizer", "<prefix>-reporter"]
}
```

### optimizer
```json
{
  "setup": "cloud-cost-optimizer", "role": "optimizer", "role_name": "Optimization Agent",
  "hostname": "<prefix>-optimizer",
  "skills": { "pilot-task-router": "Execute optimization tasks.", "pilot-audit-log": "Log actions for compliance.", "pilot-receipt": "Send receipts to reporter." },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-analyzer", "port": 1002, "topic": "cost-recommendation" },
    { "direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "action-receipt" }
  ],
  "handshakes_needed": ["<prefix>-analyzer", "<prefix>-reporter"]
}
```

### reporter
```json
{
  "setup": "cloud-cost-optimizer", "role": "reporter", "role_name": "Cost Reporter",
  "hostname": "<prefix>-reporter",
  "skills": { "pilot-webhook-bridge": "Send reports to webhooks.", "pilot-slack-bridge": "Post summaries to Slack.", "pilot-announce": "Broadcast weekly savings." },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-analyzer", "port": 1002, "topic": "cost-anomaly" },
    { "direction": "receive", "peer": "<prefix>-optimizer", "port": 1002, "topic": "action-receipt" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "cost-report" }
  ],
  "handshakes_needed": ["<prefix>-analyzer", "<prefix>-optimizer"]
}
```

## Data Flows

- `scanner -> analyzer` : resource utilization metrics (port 1002)
- `analyzer -> optimizer` : optimization recommendations (port 1002)
- `analyzer -> reporter` : cost anomaly alerts (port 1002)
- `optimizer -> reporter` : action receipts with savings (port 1002)
- `reporter -> external` : cost reports via Slack/email (port 443)

## Handshakes

```bash
# scanner <-> analyzer:
pilotctl --json handshake <prefix>-analyzer "setup: cloud-cost-optimizer"
pilotctl --json handshake <prefix>-scanner "setup: cloud-cost-optimizer"
# analyzer <-> optimizer:
pilotctl --json handshake <prefix>-optimizer "setup: cloud-cost-optimizer"
pilotctl --json handshake <prefix>-analyzer "setup: cloud-cost-optimizer"
# analyzer <-> reporter:
pilotctl --json handshake <prefix>-reporter "setup: cloud-cost-optimizer"
pilotctl --json handshake <prefix>-analyzer "setup: cloud-cost-optimizer"
# optimizer <-> reporter:
pilotctl --json handshake <prefix>-reporter "setup: cloud-cost-optimizer"
pilotctl --json handshake <prefix>-optimizer "setup: cloud-cost-optimizer"
```

## Workflow Example

```bash
# On scanner -- publish resource scan:
pilotctl --json publish <prefix>-analyzer resource-scan '{"provider":"aws","idle_instances":3,"total_monthly":12450}'

# On analyzer -- publish recommendation:
pilotctl --json publish <prefix>-optimizer cost-recommendation '{"action":"terminate","resource":"i-0a1b2c","savings":342}'

# On optimizer -- publish receipt:
pilotctl --json publish <prefix>-reporter action-receipt '{"action":"terminate","resource":"i-0a1b2c","status":"success"}'

# On reporter -- subscribe to events:
pilotctl --json subscribe cost-anomaly
pilotctl --json subscribe action-receipt
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
