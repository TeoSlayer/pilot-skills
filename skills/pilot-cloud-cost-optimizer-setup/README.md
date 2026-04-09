# Cloud Cost Optimizer Setup

A distributed FinOps pipeline that continuously scans cloud environments for waste, analyzes spending patterns, executes approved optimizations, and delivers savings reports. Four agents collaborate to keep cloud bills under control without any centralized orchestrator.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### scanner (Resource Scanner)
Continuously scans cloud environments, discovers running resources, collects billing data and utilization metrics. Publishes normalized resource snapshots to the analyzer on a configurable schedule.

**Skills:** pilot-cron, pilot-stream-data, pilot-metrics, pilot-health

### analyzer (Cost Analyzer)
Identifies idle resources, rightsizing opportunities, and anomalous spend patterns using historical trend analysis. Forwards optimization recommendations to the optimizer and flags cost anomalies to the reporter.

**Skills:** pilot-event-filter, pilot-alert, pilot-metrics

### optimizer (Optimization Agent)
Executes approved optimizations -- shutting down idle resources, scheduling reserved instances, rightsizing VMs. Logs every action and sends receipts to the reporter for the audit trail.

**Skills:** pilot-task-router, pilot-audit-log, pilot-receipt

### reporter (Cost Reporter)
Generates daily and weekly cost summaries, savings reports, and sends them to Slack and email. Aggregates data from both the analyzer (anomalies) and the optimizer (action receipts).

**Skills:** pilot-webhook-bridge, pilot-slack-bridge, pilot-announce

## Data Flow

```
scanner  --> analyzer  : resource utilization metrics (port 1002)
analyzer --> optimizer  : optimization recommendations (port 1002)
analyzer --> reporter   : cost anomalies and trends (port 1002)
optimizer --> reporter  : action receipts and savings (port 1002)
reporter --> external   : cost reports via Slack/email (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (resource scanner)
clawhub install pilot-cron pilot-stream-data pilot-metrics pilot-health
pilotctl set-hostname <your-prefix>-scanner

# On server 2 (cost analyzer)
clawhub install pilot-event-filter pilot-alert pilot-metrics
pilotctl set-hostname <your-prefix>-analyzer

# On server 3 (optimization agent)
clawhub install pilot-task-router pilot-audit-log pilot-receipt
pilotctl set-hostname <your-prefix>-optimizer

# On server 4 (cost reporter)
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-announce
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# scanner <-> analyzer (resource metrics flow)
# On scanner:
pilotctl handshake <your-prefix>-analyzer "setup: cloud-cost-optimizer"
# On analyzer:
pilotctl handshake <your-prefix>-scanner "setup: cloud-cost-optimizer"

# analyzer <-> optimizer (optimization recommendations)
# On analyzer:
pilotctl handshake <your-prefix>-optimizer "setup: cloud-cost-optimizer"
# On optimizer:
pilotctl handshake <your-prefix>-analyzer "setup: cloud-cost-optimizer"

# analyzer <-> reporter (cost anomalies)
# On analyzer:
pilotctl handshake <your-prefix>-reporter "setup: cloud-cost-optimizer"
# On reporter:
pilotctl handshake <your-prefix>-analyzer "setup: cloud-cost-optimizer"

# optimizer <-> reporter (action receipts)
# On optimizer:
pilotctl handshake <your-prefix>-reporter "setup: cloud-cost-optimizer"
# On reporter:
pilotctl handshake <your-prefix>-optimizer "setup: cloud-cost-optimizer"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-scanner -- publish a resource scan:
pilotctl publish <your-prefix>-analyzer resource-scan '{"provider":"aws","region":"us-east-1","idle_instances":["i-0a1b2c3d"],"total_monthly_cost":12450.00,"utilization_avg":0.23}'

# On <your-prefix>-analyzer -- publish a cost recommendation:
pilotctl publish <your-prefix>-optimizer cost-recommendation '{"action":"terminate","resource":"i-0a1b2c3d","type":"ec2","monthly_savings":342.50,"confidence":0.95}'

# On <your-prefix>-analyzer -- publish a cost anomaly:
pilotctl publish <your-prefix>-reporter cost-anomaly '{"service":"lambda","region":"eu-west-1","spike_pct":280,"expected_daily":45.00,"actual_daily":171.00}'

# On <your-prefix>-optimizer -- publish an action receipt:
pilotctl publish <your-prefix>-reporter action-receipt '{"action":"terminate","resource":"i-0a1b2c3d","status":"success","savings_monthly":342.50}'

# On <your-prefix>-reporter -- subscribe to incoming events:
pilotctl subscribe cost-anomaly
pilotctl subscribe action-receipt
```
