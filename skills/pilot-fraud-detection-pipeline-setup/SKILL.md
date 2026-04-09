---
name: pilot-fraud-detection-pipeline-setup
description: >
  Deploy a fraud detection pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up real-time transaction monitoring with escalation through analysis, investigation, and enforcement
  2. User is configuring agents for fraud detection, behavioral analysis, or transaction screening
  3. User asks about fraud pipelines, blocklist management, or suspicious activity workflows

  Do NOT use this skill when:
  - User wants a single blocklist check (use pilot-blocklist instead)
  - User wants to filter events without a full pipeline (use pilot-event-filter instead)
  - User only needs transaction streaming (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - fraud
  - security
  - fintech
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

# Fraud Detection Pipeline Setup

Deploy 4 agents: monitor, pattern-analyzer, investigator, and enforcer.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| monitor | `<prefix>-monitor` | pilot-stream-data, pilot-event-filter, pilot-cron, pilot-metrics | Watches transactions, flags suspicious activity |
| pattern-analyzer | `<prefix>-pattern-analyzer` | pilot-event-filter, pilot-archive, pilot-priority-queue | Behavioral analysis on flagged transactions |
| investigator | `<prefix>-investigator` | pilot-task-router, pilot-audit-log, pilot-dataset | Assembles evidence, recommends actions |
| enforcer | `<prefix>-enforcer` | pilot-blocklist, pilot-webhook-bridge, pilot-audit-log, pilot-alert | Executes blocks, feeds back to monitor |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For monitor:
clawhub install pilot-stream-data pilot-event-filter pilot-cron pilot-metrics
# For pattern-analyzer:
clawhub install pilot-event-filter pilot-archive pilot-priority-queue
# For investigator:
clawhub install pilot-task-router pilot-audit-log pilot-dataset
# For enforcer:
clawhub install pilot-blocklist pilot-webhook-bridge pilot-audit-log pilot-alert
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/fraud-detection-pipeline.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

## Manifest Templates Per Role

### monitor
```json
{
  "setup": "fraud-detection-pipeline", "role": "monitor", "role_name": "Transaction Monitor",
  "hostname": "<prefix>-monitor",
  "skills": {
    "pilot-stream-data": "Ingest real-time transaction streams from payment processors.",
    "pilot-event-filter": "Apply velocity checks, amount thresholds, and geo rules.",
    "pilot-cron": "Run scheduled batch scans for dormant account reactivation patterns.",
    "pilot-metrics": "Track flagging rates, false positive ratios, and latency."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-pattern-analyzer", "port": 1002, "topic": "flagged-transaction", "description": "Transactions exceeding risk thresholds" },
    { "direction": "receive", "peer": "<prefix>-enforcer", "port": 1002, "topic": "blocked-entity", "description": "Blocked entities for rule updates" }
  ],
  "handshakes_needed": ["<prefix>-pattern-analyzer", "<prefix>-enforcer"]
}
```

### pattern-analyzer
```json
{
  "setup": "fraud-detection-pipeline", "role": "pattern-analyzer", "role_name": "Pattern Analyzer",
  "hostname": "<prefix>-pattern-analyzer",
  "skills": {
    "pilot-event-filter": "Score transactions by device fingerprint, geo-velocity, and MCC patterns.",
    "pilot-archive": "Store behavioral profiles and historical pattern data.",
    "pilot-priority-queue": "Prioritize high-risk cases for immediate investigation."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-monitor", "port": 1002, "topic": "flagged-transaction", "description": "Flagged transactions to analyze" },
    { "direction": "send", "peer": "<prefix>-investigator", "port": 1002, "topic": "high-risk-case", "description": "High-risk cases with behavioral analysis" }
  ],
  "handshakes_needed": ["<prefix>-monitor", "<prefix>-investigator"]
}
```

### investigator
```json
{
  "setup": "fraud-detection-pipeline", "role": "investigator", "role_name": "Case Investigator",
  "hostname": "<prefix>-investigator",
  "skills": {
    "pilot-task-router": "Route cases to specialized investigation workflows.",
    "pilot-audit-log": "Maintain chain-of-custody documentation for all evidence.",
    "pilot-dataset": "Cross-reference against known fraud pattern databases."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-pattern-analyzer", "port": 1002, "topic": "high-risk-case", "description": "Cases requiring investigation" },
    { "direction": "send", "peer": "<prefix>-enforcer", "port": 1002, "topic": "fraud-verdict", "description": "Verdicts with recommended enforcement actions" }
  ],
  "handshakes_needed": ["<prefix>-pattern-analyzer", "<prefix>-enforcer"]
}
```

### enforcer
```json
{
  "setup": "fraud-detection-pipeline", "role": "enforcer", "role_name": "Fraud Enforcer",
  "hostname": "<prefix>-enforcer",
  "skills": {
    "pilot-blocklist": "Maintain and enforce block/allow lists for cards, devices, IPs.",
    "pilot-webhook-bridge": "Trigger external actions (freeze accounts, decline transactions).",
    "pilot-audit-log": "Log all enforcement decisions with full justification.",
    "pilot-alert": "Notify fraud operations team of high-severity enforcement actions."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-investigator", "port": 1002, "topic": "fraud-verdict", "description": "Verdicts to enforce" },
    { "direction": "send", "peer": "<prefix>-monitor", "port": 1002, "topic": "blocked-entity", "description": "Blocked entities for detection rule updates" }
  ],
  "handshakes_needed": ["<prefix>-investigator", "<prefix>-monitor"]
}
```

## Data Flows

- `monitor -> pattern-analyzer` : flagged transactions exceeding risk thresholds (port 1002)
- `pattern-analyzer -> investigator` : high-risk cases with behavioral analysis (port 1002)
- `investigator -> enforcer` : fraud verdicts with recommended actions (port 1002)
- `enforcer -> monitor` : blocked entities to update detection rules (port 1002)

## Workflow Example

```bash
# On monitor -- flag suspicious transaction:
pilotctl --json publish <prefix>-pattern-analyzer flagged-transaction '{"txn_id":"TXN-8839201","amount":2499.99,"velocity_1h":7,"risk_score":0.78}'
# On pattern-analyzer -- escalate high-risk case:
pilotctl --json publish <prefix>-investigator high-risk-case '{"case_id":"FRD-4401","risk_score":0.94,"patterns":["geo_impossible","device_mismatch"]}'
# On investigator -- issue verdict:
pilotctl --json publish <prefix>-enforcer fraud-verdict '{"case_id":"FRD-4401","verdict":"confirmed_fraud","action":"block_card_and_reverse"}'
# On enforcer -- block and feed back:
pilotctl --json publish <prefix>-monitor blocked-entity '{"entity_type":"card_hash","entity_id":"c4a2e","case_id":"FRD-4401"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
