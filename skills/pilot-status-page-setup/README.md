# Status Page

Deploy a status page pipeline with 3 agents that automate service monitoring, status aggregation, and public incident communication. Each agent handles one stage of the pipeline, turning endpoint health checks into a live public status page with incident notifications for subscribers.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### monitor (Service Monitor)
Pings endpoints, checks response times, detects outages and degradation. Reports per-service health status with latency metrics.

**Skills:** pilot-health, pilot-cron, pilot-metrics

### aggregator (Status Aggregator)
Combines health checks into overall system status, tracks uptime percentages, and maintains incident history. Determines when degradation becomes an incident.

**Skills:** pilot-event-filter, pilot-dataset, pilot-audit-log

### publisher (Status Publisher)
Updates the public status page, sends incident notifications to subscribers via email and Slack. Manages incident lifecycle from detection to resolution.

**Skills:** pilot-webhook-bridge, pilot-announce, pilot-slack-bridge

## Data Flow

```
monitor    --> aggregator : Per-service health check results (port 1002)
aggregator --> publisher  : System status updates and incident events (port 1002)
publisher  --> external   : Incident notifications to subscribers (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (service monitor)
clawhub install pilot-health pilot-cron pilot-metrics
pilotctl set-hostname <your-prefix>-monitor

# On server 2 (status aggregator)
clawhub install pilot-event-filter pilot-dataset pilot-audit-log
pilotctl set-hostname <your-prefix>-aggregator

# On server 3 (status publisher)
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
pilotctl set-hostname <your-prefix>-publisher
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# monitor <-> aggregator
# On monitor:
pilotctl handshake <your-prefix>-aggregator "setup: status-page"
# On aggregator:
pilotctl handshake <your-prefix>-monitor "setup: status-page"

# aggregator <-> publisher
# On aggregator:
pilotctl handshake <your-prefix>-publisher "setup: status-page"
# On publisher:
pilotctl handshake <your-prefix>-aggregator "setup: status-page"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-aggregator -- subscribe to health checks from monitor:
pilotctl subscribe <your-prefix>-monitor health-check

# On <your-prefix>-publisher -- subscribe to status updates:
pilotctl subscribe <your-prefix>-aggregator status-update

# On <your-prefix>-monitor -- publish a health check:
pilotctl publish <your-prefix>-aggregator health-check '{"service":"api-gateway","endpoint":"https://api.acme.com/health","status":"degraded","response_ms":2340,"threshold_ms":500,"timestamp":"2025-03-15T14:22:00Z"}'

# On <your-prefix>-aggregator -- publish a status update to the publisher:
pilotctl publish <your-prefix>-publisher status-update '{"overall_status":"degraded","incident":true,"incident_id":"INC-2025-0018","affected_services":["api-gateway"],"uptime_24h":99.2,"message":"API gateway experiencing elevated response times"}'

# The publisher sends incident notification to subscribers:
pilotctl publish <your-prefix>-publisher incident-notification '{"channel":"#incidents","text":"Incident INC-2025-0018: API gateway degraded - elevated response times detected","severity":"warning","status_page_url":"https://status.acme.com","subscribers_notified":142}'
```
