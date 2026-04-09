# Security Operations Center Setup

A SOC pipeline that collects security events, analyzes patterns, replays incidents for forensics, and enforces blocks automatically. The enforcer maintains a live blocklist and can quarantine compromised nodes. A dashboard agent provides real-time network visibility.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### collector (Log Collector)
Aggregates security events from all nodes -- auth failures, connection attempts, anomalous traffic. Streams events to the analyzer in real time.

**Skills:** pilot-event-log, pilot-audit-log, pilot-stream-data, pilot-cron

### analyzer (Threat Analyzer)
Filters and correlates events, detects attack patterns, classifies threats by severity. Can replay past events for forensic investigation.

**Skills:** pilot-event-filter, pilot-event-replay, pilot-alert, pilot-priority-queue

### enforcer (Threat Enforcer)
Receives threat verdicts and acts -- adds IPs to blocklist, quarantines compromised agents, triggers incident webhooks. Maintains a live deny-list.

**Skills:** pilot-blocklist, pilot-quarantine, pilot-webhook-bridge, pilot-audit-log

### dashboard (SOC Dashboard)
Visualizes network topology, active threats, blocked actors, and overall security posture. Sends summary reports to Slack.

**Skills:** pilot-metrics, pilot-slack-bridge, pilot-network-map, pilot-mesh-status

## Data Flow

```
collector --> analyzer  : Streams raw security events (port 1002)
analyzer  --> enforcer  : Sends threat verdicts for enforcement (port 1002)
analyzer  --> dashboard : Sends classified threats for display (port 1002)
enforcer  --> dashboard : Reports enforcement actions taken (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On log collection node
clawhub install pilot-event-log pilot-audit-log pilot-stream-data pilot-cron
pilotctl set-hostname <your-prefix>-collector

# On analysis node
clawhub install pilot-event-filter pilot-event-replay pilot-alert pilot-priority-queue
pilotctl set-hostname <your-prefix>-analyzer

# On enforcement node
clawhub install pilot-blocklist pilot-quarantine pilot-webhook-bridge pilot-audit-log
pilotctl set-hostname <your-prefix>-enforcer

# On dashboard node
clawhub install pilot-metrics pilot-slack-bridge pilot-network-map pilot-mesh-status
pilotctl set-hostname <your-prefix>-dashboard
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# collector <-> analyzer
# On collector:
pilotctl handshake <your-prefix>-analyzer "soc pipeline"
# On analyzer:
pilotctl handshake <your-prefix>-collector "soc pipeline"

# analyzer <-> enforcer
# On analyzer:
pilotctl handshake <your-prefix>-enforcer "soc pipeline"
# On enforcer:
pilotctl handshake <your-prefix>-analyzer "soc pipeline"

# analyzer <-> dashboard
# On analyzer:
pilotctl handshake <your-prefix>-dashboard "soc pipeline"
# On dashboard:
pilotctl handshake <your-prefix>-analyzer "soc pipeline"

# enforcer <-> dashboard
# On enforcer:
pilotctl handshake <your-prefix>-dashboard "soc pipeline"
# On dashboard:
pilotctl handshake <your-prefix>-enforcer "soc pipeline"
```

### 3. Verify

```bash
pilotctl trust
```
