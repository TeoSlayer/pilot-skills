# Log Analytics

Deploy a log analytics system with 4 agents that collect, parse, alert on, and visualize log data. A collector aggregates logs from servers, containers, and applications, a parser extracts structured fields and identifies error patterns, an alerter detects anomalies and fires notifications, and a dashboard provides search and visualization with drill-down capabilities.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### collector (Log Collector)
Aggregates logs from servers, containers, and applications. Normalizes disparate formats into a unified schema and handles backpressure from high-volume sources.

**Skills:** pilot-stream-data, pilot-archive, pilot-compress

### parser (Log Parser)
Extracts structured fields from raw logs, parses stack traces, and identifies recurring error patterns. Tags events with severity and component metadata.

**Skills:** pilot-event-filter, pilot-task-router, pilot-dataset

### alerter (Anomaly Alerter)
Detects log volume spikes, error rate anomalies, and novel error patterns using baseline comparisons. Fires alerts when thresholds are breached.

**Skills:** pilot-alert, pilot-metrics, pilot-cron

### dashboard (Log Dashboard)
Provides full-text search, time-series visualization, and drill-down into log data. Generates periodic reports on system health and error trends.

**Skills:** pilot-webhook-bridge, pilot-slack-bridge, pilot-announce

## Data Flow

```
collector --> parser    : Raw normalized logs from all sources (port 1002)
parser    --> alerter   : Parsed events with structured fields and severity (port 1002)
alerter   --> dashboard : Anomaly alerts with context and baseline comparisons (port 1002)
dashboard --> external  : Log reports to dashboards and Slack channels (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (log collector)
clawhub install pilot-stream-data pilot-archive pilot-compress
pilotctl set-hostname <your-prefix>-collector

# On server 2 (log parser)
clawhub install pilot-event-filter pilot-task-router pilot-dataset
pilotctl set-hostname <your-prefix>-parser

# On server 3 (anomaly alerter)
clawhub install pilot-alert pilot-metrics pilot-cron
pilotctl set-hostname <your-prefix>-alerter

# On server 4 (log dashboard)
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-announce
pilotctl set-hostname <your-prefix>-dashboard
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# collector <-> parser
# On collector:
pilotctl handshake <your-prefix>-parser "setup: log-analytics"
# On parser:
pilotctl handshake <your-prefix>-collector "setup: log-analytics"

# parser <-> alerter
# On parser:
pilotctl handshake <your-prefix>-alerter "setup: log-analytics"
# On alerter:
pilotctl handshake <your-prefix>-parser "setup: log-analytics"

# alerter <-> dashboard
# On alerter:
pilotctl handshake <your-prefix>-dashboard "setup: log-analytics"
# On dashboard:
pilotctl handshake <your-prefix>-alerter "setup: log-analytics"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-parser -- subscribe to raw logs from collector:
pilotctl subscribe <your-prefix>-collector raw-log

# On <your-prefix>-collector -- publish a raw log event:
pilotctl publish <your-prefix>-parser raw-log '{"source":"nginx-prod-01","timestamp":"2026-04-09T15:32:01Z","level":"error","message":"upstream timed out (110: Connection timed out)","fields":{"status":504,"upstream":"10.0.2.15:8080","request":"GET /api/v2/orders","duration_ms":30001}}'

# On <your-prefix>-alerter -- subscribe to parsed events from parser:
pilotctl subscribe <your-prefix>-parser parsed-event

# On <your-prefix>-parser -- publish a parsed event:
pilotctl publish <your-prefix>-alerter parsed-event '{"source":"nginx-prod-01","level":"error","category":"upstream_timeout","component":"nginx","structured":{"upstream":"10.0.2.15:8080","endpoint":"/api/v2/orders","status":504,"duration_ms":30001},"pattern_id":"NGINX-TIMEOUT-001","occurrences_1h":47}'

# On <your-prefix>-dashboard -- subscribe to anomaly alerts from alerter:
pilotctl subscribe <your-prefix>-alerter anomaly-alert

# On <your-prefix>-alerter -- publish an anomaly alert:
pilotctl publish <your-prefix>-dashboard anomaly-alert '{"alert_id":"ALR-7829","type":"error_spike","pattern_id":"NGINX-TIMEOUT-001","current_rate":47,"baseline_rate":3,"severity":"critical","affected_components":["nginx-prod-01","orders-api"],"started_at":"2026-04-09T15:20:00Z"}'

# On <your-prefix>-dashboard -- publish a log report:
pilotctl publish <your-prefix>-dashboard log-report '{"period":"2026-04-09T15:00:00Z/PT1H","total_events":284000,"errors":1290,"error_rate":0.0045,"top_patterns":[{"id":"NGINX-TIMEOUT-001","count":47,"severity":"critical"}],"anomalies_detected":2}'
```
