---
name: pilot-etl-data-pipeline-setup
description: >
  Deploy a five-stage ETL data pipeline with 5 agents.

  Use this skill when:
  1. User wants to set up an ETL or data processing pipeline
  2. User is configuring an ingestion, transform, validation, load, or reporting agent
  3. User asks about data pipeline orchestration across agents

  Do NOT use this skill when:
  - User wants to transfer a single dataset (use pilot-dataset instead)
  - User wants to stream data once (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - etl
  - data-pipeline
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

# ETL Data Pipeline Setup

Deploy 5 agents: ingest, transform, validate, load, and report.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| ingest | `<prefix>-ingest` | pilot-s3-bridge, pilot-database-bridge, pilot-task-chain, pilot-cron | Pulls raw data on schedule |
| transform | `<prefix>-transform` | pilot-task-router, pilot-stream-data, pilot-task-parallel | Parallel data processing |
| validate | `<prefix>-validate` | pilot-task-router, pilot-audit-log, pilot-alert, pilot-quarantine | Quality checks, quarantine |
| loader | `<prefix>-loader` | pilot-database-bridge, pilot-task-chain, pilot-receipt | Writes to target stores |
| reporter | `<prefix>-reporter` | pilot-webhook-bridge, pilot-metrics, pilot-slack-bridge, pilot-cron | Dashboards and reports |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# ingest:
clawhub install pilot-s3-bridge pilot-database-bridge pilot-task-chain pilot-cron
# transform:
clawhub install pilot-task-router pilot-stream-data pilot-task-parallel
# validate:
clawhub install pilot-task-router pilot-audit-log pilot-alert pilot-quarantine
# loader:
clawhub install pilot-database-bridge pilot-task-chain pilot-receipt
# reporter:
clawhub install pilot-webhook-bridge pilot-metrics pilot-slack-bridge pilot-cron
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/etl-data-pipeline.json`.

**Step 4:** Handshake with adjacent pipeline stages.

## Manifest Templates Per Role

### ingest
```json
{
  "setup": "etl-data-pipeline", "role": "ingest", "role_name": "Data Ingestion",
  "hostname": "<prefix>-ingest",
  "skills": {
    "pilot-s3-bridge": "Pull raw data from S3 buckets.",
    "pilot-database-bridge": "Extract from source databases.",
    "pilot-task-chain": "Chain ingestion steps sequentially.",
    "pilot-cron": "Schedule periodic data pulls."
  },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-transform", "port": 1001, "topic": "ingest-batch", "description": "Raw data batches" }],
  "handshakes_needed": ["<prefix>-transform"]
}
```

### transform
```json
{
  "setup": "etl-data-pipeline", "role": "transform", "role_name": "Data Transformer",
  "hostname": "<prefix>-transform",
  "skills": {
    "pilot-task-router": "Accept transform tasks from ingest.",
    "pilot-stream-data": "Stream transformed records to validator.",
    "pilot-task-parallel": "Process data in parallel for throughput."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-ingest", "port": 1001, "topic": "ingest-batch", "description": "Raw data" },
    { "direction": "send", "peer": "<prefix>-validate", "port": 1001, "topic": "transform-complete", "description": "Transformed records" }
  ],
  "handshakes_needed": ["<prefix>-ingest", "<prefix>-validate"]
}
```

### validate
```json
{
  "setup": "etl-data-pipeline", "role": "validate", "role_name": "Data Validator",
  "hostname": "<prefix>-validate",
  "skills": {
    "pilot-task-router": "Accept validation tasks.",
    "pilot-audit-log": "Log validation results.",
    "pilot-alert": "Alert on high error rates.",
    "pilot-quarantine": "Quarantine invalid records."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-transform", "port": 1001, "topic": "transform-complete", "description": "Transformed records" },
    { "direction": "send", "peer": "<prefix>-loader", "port": 1001, "topic": "validation-passed", "description": "Validated records" },
    { "direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "validation-metrics", "description": "Error rates" }
  ],
  "handshakes_needed": ["<prefix>-transform", "<prefix>-loader", "<prefix>-reporter"]
}
```

### loader
```json
{
  "setup": "etl-data-pipeline", "role": "loader", "role_name": "Data Loader",
  "hostname": "<prefix>-loader",
  "skills": {
    "pilot-database-bridge": "Write validated data to target databases.",
    "pilot-task-chain": "Chain load steps.",
    "pilot-receipt": "Issue receipts for every load batch."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-validate", "port": 1001, "topic": "validation-passed", "description": "Validated records" },
    { "direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "load-receipt", "description": "Load receipts" }
  ],
  "handshakes_needed": ["<prefix>-validate", "<prefix>-reporter"]
}
```

### reporter
```json
{
  "setup": "etl-data-pipeline", "role": "reporter", "role_name": "Pipeline Reporter",
  "hostname": "<prefix>-reporter",
  "skills": {
    "pilot-webhook-bridge": "Forward pipeline alerts to external services.",
    "pilot-metrics": "Aggregate pipeline metrics.",
    "pilot-slack-bridge": "Post daily pipeline summaries to Slack.",
    "pilot-cron": "Schedule hourly/daily report generation."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-validate", "port": 1002, "topic": "validation-metrics", "description": "Error rates" },
    { "direction": "receive", "peer": "<prefix>-loader", "port": 1002, "topic": "load-receipt", "description": "Load receipts" }
  ],
  "handshakes_needed": ["<prefix>-validate", "<prefix>-loader"]
}
```

## Data Flows

- `ingest → transform` : raw data batches (port 1001)
- `transform → validate` : transformed records (port 1001)
- `validate → loader` : validated records (port 1001)
- `loader → reporter` : load receipts (port 1002)
- `validate → reporter` : validation metrics (port 1002)

## Workflow Example

```bash
# On ingest:
pilotctl --json send-file <prefix>-transform ./data/raw/orders.csv
pilotctl --json publish <prefix>-transform ingest-batch '{"source":"s3://data/orders","rows":50000}'
# On validate:
pilotctl --json publish <prefix>-loader validation-passed '{"batch_id":"B-1042","valid":49700,"quarantined":123}'
# On loader:
pilotctl --json publish <prefix>-reporter load-receipt '{"batch_id":"B-1042","rows_loaded":49700}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
