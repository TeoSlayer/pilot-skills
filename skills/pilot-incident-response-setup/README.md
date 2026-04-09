# Incident Response Setup

A four-stage incident response pipeline. Detector agents watch for anomalies, triage classifies by severity and SLA, the remediator executes automated fixes, and the notifier keeps humans informed via Slack and email. Full audit trail at every stage.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### detector (Anomaly Detector)
Continuously monitors systems for anomalies -- unusual traffic patterns, error spikes, resource exhaustion. Logs everything and emits structured alerts.

**Skills:** pilot-watchdog, pilot-alert, pilot-audit-log, pilot-metrics

### triage (Incident Triage)
Receives raw alerts, filters noise, classifies severity (P1-P4), applies SLA policies, and routes to remediator or directly to notifier for critical issues.

**Skills:** pilot-alert, pilot-event-filter, pilot-priority-queue, pilot-sla

### remediator (Auto-Remediator)
Executes automated remediation actions -- restart services, scale resources, quarantine compromised nodes. Runs scheduled health checks via cron.

**Skills:** pilot-task-router, pilot-cron, pilot-audit-log, pilot-quarantine

### notifier (Human Notifier)
Sends incident notifications to the right channels -- Slack for awareness, email for escalation, webhooks for external integrations. Maintains a complete audit trail.

**Skills:** pilot-slack-bridge, pilot-email-bridge, pilot-webhook-bridge, pilot-audit-log

## Data Flow

```
detector    --> triage     : Raw anomaly alerts for classification (port 1002)
triage      --> remediator : Actionable incidents for auto-remediation (port 1002)
triage      --> notifier   : Classified incidents for human notification (port 1002)
remediator  --> notifier   : Remediation actions taken (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On monitored infrastructure
clawhub install pilot-watchdog pilot-alert pilot-audit-log pilot-metrics
pilotctl set-hostname <your-prefix>-detector

# On triage server
clawhub install pilot-alert pilot-event-filter pilot-priority-queue pilot-sla
pilotctl set-hostname <your-prefix>-triage

# On remediation server
clawhub install pilot-task-router pilot-cron pilot-audit-log pilot-quarantine
pilotctl set-hostname <your-prefix>-remediator

# On notification server
clawhub install pilot-slack-bridge pilot-email-bridge pilot-webhook-bridge pilot-audit-log
pilotctl set-hostname <your-prefix>-notifier
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On detector:
pilotctl handshake <your-prefix>-triage "setup: incident-response"
# On triage:
pilotctl handshake <your-prefix>-detector "setup: incident-response"
# On notifier:
pilotctl handshake <your-prefix>-remediator "setup: incident-response"
# On remediator:
pilotctl handshake <your-prefix>-notifier "setup: incident-response"
# On notifier:
pilotctl handshake <your-prefix>-triage "setup: incident-response"
# On triage:
pilotctl handshake <your-prefix>-notifier "setup: incident-response"
# On remediator:
pilotctl handshake <your-prefix>-triage "setup: incident-response"
# On triage:
pilotctl handshake <your-prefix>-remediator "setup: incident-response"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-detector — publish an anomaly alert:
pilotctl publish <your-prefix>-triage anomaly-detected '{"source":"web-01","type":"error_spike","rate":450,"threshold":100}'

# On <your-prefix>-triage — classify and route to remediator:
pilotctl publish <your-prefix>-remediator incident-action '{"id":"INC-2847","severity":"P1","action":"restart_service","target":"web-01"}'
pilotctl publish <your-prefix>-notifier incident-alert '{"id":"INC-2847","severity":"P1","summary":"Error spike on web-01 (450/min)"}'

# On <your-prefix>-remediator — execute and report:
pilotctl publish <your-prefix>-notifier remediation-complete '{"id":"INC-2847","action":"restart_service","result":"success","duration_s":12}'

# On <your-prefix>-notifier — forward to Slack:
pilotctl publish <your-prefix>-notifier slack-forward '{"channel":"#incidents","text":"P1 INC-2847 resolved: web-01 restarted (12s)"}'
```
