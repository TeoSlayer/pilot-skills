# Fleet Health Monitor Setup

Deploy monitoring agents across your fleet that continuously check service health, aggregate metrics, and route alerts to Slack or PagerDuty. Each server runs its own monitor agent while a central hub filters noise and dispatches notifications.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### web-monitor (Web Server Monitor)
Watches nginx/app health, CPU, memory, and response times. Emits alert events when thresholds are breached.

**Skills:** pilot-health, pilot-alert, pilot-metrics

### db-monitor (Database Monitor)
Monitors database connections, query latency, replication lag, and disk usage. Emits alerts on anomalies.

**Skills:** pilot-health, pilot-alert, pilot-metrics

### alert-hub (Alert Aggregator)
Receives alerts from all monitors, filters duplicates and noise, then forwards critical alerts to Slack and PagerDuty via webhooks.

**Skills:** pilot-webhook-bridge, pilot-alert, pilot-event-filter, pilot-slack-bridge

## Data Flow

```
web-monitor --> alert-hub : Health check failures and metric anomalies (port 1002)
db-monitor  --> alert-hub : Database alerts and replication warnings (port 1002)
alert-hub   --> external  : Filtered alerts to Slack and PagerDuty (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (web server)
clawhub install pilot-health pilot-alert pilot-metrics
pilotctl set-hostname <your-prefix>-web-monitor

# On server 2 (database)
clawhub install pilot-health pilot-alert pilot-metrics
pilotctl set-hostname <your-prefix>-db-monitor

# On server 3 (alert aggregator)
clawhub install pilot-webhook-bridge pilot-alert pilot-event-filter pilot-slack-bridge
pilotctl set-hostname <your-prefix>-alert-hub
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On alert-hub:
pilotctl handshake <your-prefix>-db-monitor "setup: fleet-health-monitor"
# On db-monitor:
pilotctl handshake <your-prefix>-alert-hub "setup: fleet-health-monitor"
# On alert-hub:
pilotctl handshake <your-prefix>-web-monitor "setup: fleet-health-monitor"
# On web-monitor:
pilotctl handshake <your-prefix>-alert-hub "setup: fleet-health-monitor"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-alert-hub — subscribe to health events from monitors:
pilotctl subscribe <your-prefix>-web-monitor health-alert
pilotctl subscribe <your-prefix>-db-monitor health-alert

# On <your-prefix>-web-monitor — publish a health alert:
pilotctl publish <your-prefix>-alert-hub health-alert '{"host":"web-01","status":"critical","cpu":95,"mem":88}'

# On <your-prefix>-db-monitor — publish a database alert:
pilotctl publish <your-prefix>-alert-hub health-alert '{"host":"db-01","status":"warning","disk_pct":88,"repl_lag_ms":450}'

# The alert-hub receives both events and forwards to Slack:
pilotctl publish <your-prefix>-alert-hub slack-forward '{"channel":"#ops","text":"CRITICAL: web-01 CPU 95%"}'
```
