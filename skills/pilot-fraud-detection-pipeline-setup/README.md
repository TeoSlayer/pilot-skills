# Fraud Detection Pipeline Setup

A real-time fraud detection pipeline that processes transaction streams through four escalation stages. The monitor watches live transactions for threshold breaches and velocity anomalies, the pattern analyzer performs deep behavioral analysis on flagged items, the investigator assembles evidence packages for high-confidence cases, and the enforcer executes blocking actions and feeds blocked entities back into the monitoring loop.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### monitor (Transaction Monitor)
Watches real-time transaction streams, applies velocity checks and amount thresholds, flags suspicious activity for deeper analysis. Tracks transactions per second, monitors for card-testing patterns, and detects geographic impossibilities.

**Skills:** pilot-stream-data, pilot-event-filter, pilot-cron, pilot-metrics

### pattern-analyzer (Pattern Analyzer)
Runs behavioral analysis on flagged transactions -- device fingerprinting, geo-velocity checks, merchant category patterns, and account linkage graphs. Scores each case by risk level and forwards high-risk cases for investigation.

**Skills:** pilot-event-filter, pilot-archive, pilot-priority-queue

### investigator (Case Investigator)
Assembles evidence packages for high-confidence fraud cases, cross-references against known fraud patterns and historical case data, and recommends specific enforcement actions. Maintains detailed case files with chain-of-custody documentation.

**Skills:** pilot-task-router, pilot-audit-log, pilot-dataset

### enforcer (Fraud Enforcer)
Executes blocking actions -- freezing accounts, declining transactions, triggering customer verification flows -- and logs all enforcement decisions. Feeds blocked entities back to the monitor to update real-time detection rules.

**Skills:** pilot-blocklist, pilot-webhook-bridge, pilot-audit-log, pilot-alert

## Data Flow

```
monitor          --> pattern-analyzer : Flagged transactions exceeding risk thresholds (port 1002)
pattern-analyzer --> investigator     : High-risk cases with behavioral analysis (port 1002)
investigator     --> enforcer         : Fraud verdicts with recommended actions (port 1002)
enforcer         --> monitor          : Blocked entities to update detection rules (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On transaction monitoring server
clawhub install pilot-stream-data pilot-event-filter pilot-cron pilot-metrics
pilotctl set-hostname <your-prefix>-monitor

# On pattern analysis server
clawhub install pilot-event-filter pilot-archive pilot-priority-queue
pilotctl set-hostname <your-prefix>-pattern-analyzer

# On investigation server
clawhub install pilot-task-router pilot-audit-log pilot-dataset
pilotctl set-hostname <your-prefix>-investigator

# On enforcement server
clawhub install pilot-blocklist pilot-webhook-bridge pilot-audit-log pilot-alert
pilotctl set-hostname <your-prefix>-enforcer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# monitor <-> pattern-analyzer (flagged transactions)
# On monitor:
pilotctl handshake <your-prefix>-pattern-analyzer "setup: fraud-detection-pipeline"
# On pattern-analyzer:
pilotctl handshake <your-prefix>-monitor "setup: fraud-detection-pipeline"

# pattern-analyzer <-> investigator (high-risk cases)
# On pattern-analyzer:
pilotctl handshake <your-prefix>-investigator "setup: fraud-detection-pipeline"
# On investigator:
pilotctl handshake <your-prefix>-pattern-analyzer "setup: fraud-detection-pipeline"

# investigator <-> enforcer (fraud verdicts)
# On investigator:
pilotctl handshake <your-prefix>-enforcer "setup: fraud-detection-pipeline"
# On enforcer:
pilotctl handshake <your-prefix>-investigator "setup: fraud-detection-pipeline"

# enforcer <-> monitor (blocked entities feedback loop)
# On enforcer:
pilotctl handshake <your-prefix>-monitor "setup: fraud-detection-pipeline"
# On monitor:
pilotctl handshake <your-prefix>-enforcer "setup: fraud-detection-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-monitor -- flag a suspicious transaction:
pilotctl publish <your-prefix>-pattern-analyzer flagged-transaction '{"txn_id":"TXN-8839201","card_hash":"c4a2e...","amount":2499.99,"currency":"USD","merchant":"Electronics Hub","mcc":"5732","country":"RO","velocity_1h":7,"avg_velocity_1h":1.2,"risk_score":0.78,"flags":["velocity_spike","foreign_merchant","high_amount"]}'

# On <your-prefix>-pattern-analyzer -- escalate as high-risk:
pilotctl publish <your-prefix>-investigator high-risk-case '{"case_id":"FRD-4401","txn_ids":["TXN-8839201","TXN-8839198","TXN-8839195"],"risk_score":0.94,"patterns":["geo_impossible:US_to_RO_in_2min","device_mismatch:new_fingerprint","velocity:7x_above_baseline"],"linked_accounts":["card_hash:c4a2e","device:fp_9x3k"]}'

# On <your-prefix>-investigator -- issue fraud verdict:
pilotctl publish <your-prefix>-enforcer fraud-verdict '{"case_id":"FRD-4401","verdict":"confirmed_fraud","confidence":0.97,"action":"block_card_and_reverse","evidence_refs":["geo_analysis.json","device_graph.json","velocity_chart.png"],"affected_txns":["TXN-8839201","TXN-8839198","TXN-8839195"]}'

# On <your-prefix>-enforcer -- block and feed back to monitor:
pilotctl publish <your-prefix>-monitor blocked-entity '{"entity_type":"card_hash","entity_id":"c4a2e","action":"blocked","case_id":"FRD-4401","ttl_hours":720,"also_blocked":["device:fp_9x3k"],"timestamp":"2026-04-09T15:42:00Z"}'
```
