---
name: pilot-brand-protection-setup
description: >
  Deploy a brand protection system with 4 agents for scanning, classification, enforcement, and reporting.

  Use this skill when:
  1. User wants to set up brand monitoring for counterfeits, impersonation, or trademark violations
  2. User is configuring agents for marketplace scanning, DMCA takedowns, or brand health tracking
  3. User asks about brand protection pipelines, takedown workflows, or violation classification

  Do NOT use this skill when:
  - User wants to stream a single data feed (use pilot-stream-data instead)
  - User wants to send a one-off webhook notification (use pilot-webhook-bridge instead)
  - User only needs event filtering (use pilot-event-filter instead)
tags:
  - pilot-protocol
  - setup
  - brand-protection
  - compliance
  - monitoring
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

# Brand Protection Setup

Deploy 4 agents: scanner, classifier, enforcer, and dashboard.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| scanner | `<prefix>-scanner` | pilot-stream-data, pilot-cron, pilot-archive | Crawls marketplaces and social media for brand violations |
| classifier | `<prefix>-classifier` | pilot-event-filter, pilot-task-router, pilot-metrics | Classifies violations by type, severity, and platform |
| enforcer | `<prefix>-enforcer` | pilot-webhook-bridge, pilot-audit-log, pilot-receipt | Files DMCA notices and platform reports, tracks status |
| dashboard | `<prefix>-dashboard` | pilot-metrics, pilot-slack-bridge, pilot-announce | Visualizes brand health, violation trends, enforcement rates |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For scanner:
clawhub install pilot-stream-data pilot-cron pilot-archive
# For classifier:
clawhub install pilot-event-filter pilot-task-router pilot-metrics
# For enforcer:
clawhub install pilot-webhook-bridge pilot-audit-log pilot-receipt
# For dashboard:
clawhub install pilot-metrics pilot-slack-bridge pilot-announce
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/brand-protection.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### scanner
```json
{
  "setup": "brand-protection", "setup_name": "Brand Protection",
  "role": "scanner", "role_name": "Brand Scanner",
  "hostname": "<prefix>-scanner",
  "description": "Crawls marketplaces, social media, and domains for unauthorized brand usage and counterfeits.",
  "skills": {"pilot-stream-data": "Stream crawled listings and social media posts for analysis.", "pilot-cron": "Schedule periodic scans across configured platforms.", "pilot-archive": "Archive raw scan results and evidence snapshots."},
  "peers": [{"role": "classifier", "hostname": "<prefix>-classifier", "description": "Receives brand violations for classification"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-classifier", "port": 1002, "topic": "brand-violation", "description": "Brand violations detected across platforms"}],
  "handshakes_needed": ["<prefix>-classifier"]
}
```

### classifier
```json
{
  "setup": "brand-protection", "setup_name": "Brand Protection",
  "role": "classifier", "role_name": "Threat Classifier",
  "hostname": "<prefix>-classifier",
  "description": "Classifies violations by type (counterfeit, impersonation, trademark), severity, and platform.",
  "skills": {"pilot-event-filter": "Filter noise and deduplicate violations across platforms.", "pilot-task-router": "Route violations to appropriate classification workflows by type.", "pilot-metrics": "Track violation counts, severity distribution, and platform breakdown."},
  "peers": [{"role": "scanner", "hostname": "<prefix>-scanner", "description": "Sends brand violations"}, {"role": "enforcer", "hostname": "<prefix>-enforcer", "description": "Receives classified threats"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-scanner", "port": 1002, "topic": "brand-violation", "description": "Brand violations detected across platforms"}, {"direction": "send", "peer": "<prefix>-enforcer", "port": 1002, "topic": "classified-threat", "description": "Classified threats with type, severity, and priority"}],
  "handshakes_needed": ["<prefix>-scanner", "<prefix>-enforcer"]
}
```

### enforcer
```json
{
  "setup": "brand-protection", "setup_name": "Brand Protection",
  "role": "enforcer", "role_name": "Takedown Enforcer",
  "hostname": "<prefix>-enforcer",
  "description": "Files DMCA notices, platform reports, and cease-and-desist requests. Tracks enforcement status.",
  "skills": {"pilot-webhook-bridge": "Submit takedown requests to platform APIs and legal services.", "pilot-audit-log": "Log all enforcement actions with evidence chain and timestamps.", "pilot-receipt": "Generate and store receipts for filed takedown notices."},
  "peers": [{"role": "classifier", "hostname": "<prefix>-classifier", "description": "Sends classified threats"}, {"role": "dashboard", "hostname": "<prefix>-dashboard", "description": "Receives enforcement actions"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-classifier", "port": 1002, "topic": "classified-threat", "description": "Classified threats to enforce"}, {"direction": "send", "peer": "<prefix>-dashboard", "port": 1002, "topic": "enforcement-action", "description": "Enforcement actions with status and outcomes"}],
  "handshakes_needed": ["<prefix>-classifier", "<prefix>-dashboard"]
}
```

### dashboard
```json
{
  "setup": "brand-protection", "setup_name": "Brand Protection",
  "role": "dashboard", "role_name": "Brand Dashboard",
  "hostname": "<prefix>-dashboard",
  "description": "Visualizes brand health metrics, violation trends, and enforcement success rates.",
  "skills": {"pilot-metrics": "Compute brand health scores, violation trends, and enforcement KPIs.", "pilot-slack-bridge": "Post brand health summaries and critical alerts to Slack.", "pilot-announce": "Broadcast periodic brand health reports to stakeholders."},
  "peers": [{"role": "enforcer", "hostname": "<prefix>-enforcer", "description": "Sends enforcement actions"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-enforcer", "port": 1002, "topic": "enforcement-action", "description": "Enforcement actions with status and outcomes"}, {"direction": "send", "peer": "external", "port": 443, "topic": "brand-report", "description": "Brand health reports to stakeholders"}],
  "handshakes_needed": ["<prefix>-enforcer"]
}
```

## Data Flows

- `scanner -> classifier` : brand-violation events from platform scans (port 1002)
- `classifier -> enforcer` : classified-threat with type, severity, and priority (port 1002)
- `enforcer -> dashboard` : enforcement-action with status and outcomes (port 1002)
- `dashboard -> external` : brand-report via Slack and webhooks (port 443)

## Handshakes

```bash
# scanner <-> classifier:
pilotctl --json handshake <prefix>-classifier "setup: brand-protection"
pilotctl --json handshake <prefix>-scanner "setup: brand-protection"
# classifier <-> enforcer:
pilotctl --json handshake <prefix>-enforcer "setup: brand-protection"
pilotctl --json handshake <prefix>-classifier "setup: brand-protection"
# enforcer <-> dashboard:
pilotctl --json handshake <prefix>-dashboard "setup: brand-protection"
pilotctl --json handshake <prefix>-enforcer "setup: brand-protection"
```

## Workflow Example

```bash
# On scanner -- publish detected violation:
pilotctl --json publish <prefix>-classifier brand-violation '{"violation_id":"BV-20481","platform":"amazon","type":"counterfeit","confidence":0.91}'
# On classifier -- publish classified threat:
pilotctl --json publish <prefix>-enforcer classified-threat '{"violation_id":"BV-20481","severity":"high","action":"dmca_takedown"}'
# On enforcer -- publish enforcement action:
pilotctl --json publish <prefix>-dashboard enforcement-action '{"violation_id":"BV-20481","action":"dmca_filed","status":"pending"}'
# On dashboard -- publish brand report:
pilotctl --json publish <prefix>-dashboard brand-report '{"period":"2026-W15","violations":23,"takedowns_filed":18,"success_rate":0.78}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
