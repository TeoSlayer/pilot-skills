---
name: pilot-incident-response-setup
description: >
  Deploy an incident response pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up automated incident detection and response
  2. User is configuring a detector, triage, remediation, or notification agent
  3. User asks about automated alerting, remediation, or escalation workflows

  Do NOT use this skill when:
  - User wants a single watchdog check (use pilot-watchdog instead)
  - User wants to send a one-off alert (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - incident-response
  - security
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

# Incident Response Setup

Deploy 4 agents: detector, triage, remediator, and notifier.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| detector | `<prefix>-detector` | pilot-watchdog, pilot-alert, pilot-audit-log, pilot-metrics | Monitors for anomalies |
| triage | `<prefix>-triage` | pilot-alert, pilot-event-filter, pilot-priority-queue, pilot-sla | Classifies and routes incidents |
| remediator | `<prefix>-remediator` | pilot-task-router, pilot-cron, pilot-audit-log, pilot-quarantine | Executes automated fixes |
| notifier | `<prefix>-notifier` | pilot-slack-bridge, pilot-email-bridge, pilot-webhook-bridge, pilot-audit-log | Notifies humans |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For detector:
clawhub install pilot-watchdog pilot-alert pilot-audit-log pilot-metrics
# For triage:
clawhub install pilot-alert pilot-event-filter pilot-priority-queue pilot-sla
# For remediator:
clawhub install pilot-task-router pilot-cron pilot-audit-log pilot-quarantine
# For notifier:
clawhub install pilot-slack-bridge pilot-email-bridge pilot-webhook-bridge pilot-audit-log
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/incident-response.json`.

**Step 4:** Tell the user to initiate handshakes.

## Manifest Templates Per Role

### detector
```json
{
  "setup": "incident-response", "role": "detector", "role_name": "Anomaly Detector",
  "hostname": "<prefix>-detector",
  "skills": {
    "pilot-watchdog": "Monitor for unusual traffic, error spikes, resource exhaustion.",
    "pilot-alert": "Emit structured anomaly alerts to triage.",
    "pilot-audit-log": "Log all detected anomalies for forensics.",
    "pilot-metrics": "Track detection rates, false positive ratios."
  },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-triage", "port": 1002, "topic": "anomaly-detected", "description": "Raw anomaly alerts" }],
  "handshakes_needed": ["<prefix>-triage"]
}
```

### triage
```json
{
  "setup": "incident-response", "role": "triage", "role_name": "Incident Triage",
  "hostname": "<prefix>-triage",
  "skills": {
    "pilot-alert": "Receive raw alerts, classify severity (P1-P4).",
    "pilot-event-filter": "Filter noise and duplicates.",
    "pilot-priority-queue": "Queue incidents by priority for routing.",
    "pilot-sla": "Apply SLA policies to determine response deadlines."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-detector", "port": 1002, "topic": "anomaly-detected", "description": "Raw alerts" },
    { "direction": "send", "peer": "<prefix>-remediator", "port": 1002, "topic": "incident-action", "description": "Actionable incidents" },
    { "direction": "send", "peer": "<prefix>-notifier", "port": 1002, "topic": "incident-alert", "description": "Classified incidents" }
  ],
  "handshakes_needed": ["<prefix>-detector", "<prefix>-remediator", "<prefix>-notifier"]
}
```

### remediator
```json
{
  "setup": "incident-response", "role": "remediator", "role_name": "Auto-Remediator",
  "hostname": "<prefix>-remediator",
  "skills": {
    "pilot-task-router": "Execute remediation actions (restart, scale, quarantine).",
    "pilot-cron": "Run scheduled health checks.",
    "pilot-audit-log": "Log all remediation actions.",
    "pilot-quarantine": "Isolate compromised nodes."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-triage", "port": 1002, "topic": "incident-action", "description": "Actionable incidents" },
    { "direction": "send", "peer": "<prefix>-notifier", "port": 1002, "topic": "remediation-complete", "description": "Remediation reports" }
  ],
  "handshakes_needed": ["<prefix>-triage", "<prefix>-notifier"]
}
```

### notifier
```json
{
  "setup": "incident-response", "role": "notifier", "role_name": "Human Notifier",
  "hostname": "<prefix>-notifier",
  "skills": {
    "pilot-slack-bridge": "Post incident alerts to Slack channels.",
    "pilot-email-bridge": "Send escalation emails for P1 incidents.",
    "pilot-webhook-bridge": "Trigger external integrations (PagerDuty, Opsgenie).",
    "pilot-audit-log": "Log all notifications sent."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-triage", "port": 1002, "topic": "incident-alert", "description": "Classified incidents" },
    { "direction": "receive", "peer": "<prefix>-remediator", "port": 1002, "topic": "remediation-complete", "description": "Remediation reports" }
  ],
  "handshakes_needed": ["<prefix>-triage", "<prefix>-remediator"]
}
```

## Data Flows

- `detector → triage` : raw anomaly alerts (port 1002)
- `triage → remediator` : actionable incidents (port 1002)
- `triage → notifier` : classified incidents (port 1002)
- `remediator → notifier` : remediation reports (port 1002)

## Workflow Example

```bash
# On detector:
pilotctl --json publish <prefix>-triage anomaly-detected '{"source":"web-01","type":"error_spike","rate":450}'
# On triage:
pilotctl --json publish <prefix>-remediator incident-action '{"id":"INC-2847","severity":"P1","action":"restart_service"}'
pilotctl --json publish <prefix>-notifier incident-alert '{"id":"INC-2847","severity":"P1","summary":"Error spike on web-01"}'
# On remediator:
pilotctl --json publish <prefix>-notifier remediation-complete '{"id":"INC-2847","action":"restart_service","result":"success"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
