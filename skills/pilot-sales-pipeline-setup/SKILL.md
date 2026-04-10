---
name: pilot-sales-pipeline-setup
description: >
  Deploy a sales pipeline with 4 agents that automate lead prospecting,
  qualification, outreach, and CRM synchronization.

  Use this skill when:
  1. User wants to set up a sales pipeline or lead generation system
  2. User is configuring an agent as part of a sales or CRM workflow
  3. User asks about lead scoring, outreach automation, or pipeline management across agents

  Do NOT use this skill when:
  - User wants to send a single email (use pilot-email-bridge instead)
  - User wants a one-off webhook call (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - sales
  - pipeline
  - crm
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

# Sales Pipeline Setup

Deploy 4 agents that automate the full sales funnel from lead discovery to CRM sync.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| prospector | `<prefix>-prospector` | pilot-discover, pilot-stream-data, pilot-metrics | Finds and scores leads from web and inbound sources |
| qualifier | `<prefix>-qualifier` | pilot-event-filter, pilot-task-router, pilot-dataset | Evaluates leads against ICP, enriches, categorizes by tier |
| outreach | `<prefix>-outreach` | pilot-email-bridge, pilot-cron, pilot-receipt | Sends personalized email sequences, tracks engagement |
| crm-sync | `<prefix>-crm-sync` | pilot-webhook-bridge, pilot-audit-log, pilot-slack-bridge | Syncs activity to CRM, maintains deal stages, reports forecasts |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# prospector:
clawhub install pilot-discover pilot-stream-data pilot-metrics
# qualifier:
clawhub install pilot-event-filter pilot-task-router pilot-dataset
# outreach:
clawhub install pilot-email-bridge pilot-cron pilot-receipt
# crm-sync:
clawhub install pilot-webhook-bridge pilot-audit-log pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/sales-pipeline.json << 'MANIFEST'
<USE ROLE TEMPLATE BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### prospector
```json
{"setup":"sales-pipeline","setup_name":"Sales Pipeline","role":"prospector","role_name":"Lead Prospector","hostname":"<prefix>-prospector","description":"Identifies potential leads from web scraping, social signals, and inbound forms. Scores leads by fit.","skills":{"pilot-discover":"Scan web sources, LinkedIn, and inbound forms for prospect signals.","pilot-stream-data":"Stream raw lead data to qualifier in real time.","pilot-metrics":"Track lead volume, source conversion rates, and fit score distribution."},"peers":[{"role":"qualifier","hostname":"<prefix>-qualifier","description":"Receives raw leads for qualification"}],"data_flows":[{"direction":"send","peer":"<prefix>-qualifier","port":1002,"topic":"raw-lead","description":"Raw leads with fit scores"}],"handshakes_needed":["<prefix>-qualifier"]}
```

### qualifier
```json
{"setup":"sales-pipeline","setup_name":"Sales Pipeline","role":"qualifier","role_name":"Lead Qualifier","hostname":"<prefix>-qualifier","description":"Evaluates leads against ICP criteria, enriches with firmographic data, categorizes by tier.","skills":{"pilot-event-filter":"Filter leads below score threshold, deduplicate.","pilot-task-router":"Route hot leads to outreach immediately, warm leads on delay.","pilot-dataset":"Store enrichment data — firmographics, technographics, intent signals."},"peers":[{"role":"prospector","hostname":"<prefix>-prospector","description":"Sends raw leads"},{"role":"outreach","hostname":"<prefix>-outreach","description":"Receives qualified leads"}],"data_flows":[{"direction":"receive","peer":"<prefix>-prospector","port":1002,"topic":"raw-lead","description":"Raw leads with fit scores"},{"direction":"send","peer":"<prefix>-outreach","port":1002,"topic":"qualified-lead","description":"Qualified leads with tier and enrichment"}],"handshakes_needed":["<prefix>-prospector","<prefix>-outreach"]}
```

### outreach
```json
{"setup":"sales-pipeline","setup_name":"Sales Pipeline","role":"outreach","role_name":"Outreach Agent","hostname":"<prefix>-outreach","description":"Generates personalized email sequences, tracks engagement, handles follow-ups.","skills":{"pilot-email-bridge":"Send personalized emails, track opens and clicks.","pilot-cron":"Schedule follow-up sequences on cadence.","pilot-receipt":"Confirm delivery and track engagement receipts."},"peers":[{"role":"qualifier","hostname":"<prefix>-qualifier","description":"Sends qualified leads"},{"role":"crm-sync","hostname":"<prefix>-crm-sync","description":"Receives engagement events"}],"data_flows":[{"direction":"receive","peer":"<prefix>-qualifier","port":1002,"topic":"qualified-lead","description":"Qualified leads with tier and enrichment"},{"direction":"send","peer":"<prefix>-crm-sync","port":1002,"topic":"engagement-event","description":"Engagement events — opens, replies, meetings"}],"handshakes_needed":["<prefix>-qualifier","<prefix>-crm-sync"]}
```

### crm-sync
```json
{"setup":"sales-pipeline","setup_name":"Sales Pipeline","role":"crm-sync","role_name":"CRM Sync Agent","hostname":"<prefix>-crm-sync","description":"Syncs all pipeline activity to CRM via webhook, maintains deal stages, reports forecasts.","skills":{"pilot-webhook-bridge":"Push deal updates and stage changes to CRM via webhook.","pilot-audit-log":"Log all pipeline activity for compliance and replay.","pilot-slack-bridge":"Post forecast summaries and deal alerts to Slack."},"peers":[{"role":"outreach","hostname":"<prefix>-outreach","description":"Sends engagement events"}],"data_flows":[{"direction":"receive","peer":"<prefix>-outreach","port":1002,"topic":"engagement-event","description":"Engagement events — opens, replies, meetings"},{"direction":"send","peer":"external","port":443,"topic":"crm-update","description":"CRM updates and forecast reports"}],"handshakes_needed":["<prefix>-outreach"]}
```

## Data Flows

- `prospector -> qualifier` : raw-lead events (port 1002)
- `qualifier -> outreach` : qualified-lead events (port 1002)
- `outreach -> crm-sync` : engagement-event events (port 1002)
- `crm-sync -> external` : CRM updates via webhook (port 443)

## Handshakes

```bash
# prospector <-> qualifier:
pilotctl --json handshake <prefix>-qualifier "setup: sales-pipeline"
pilotctl --json handshake <prefix>-prospector "setup: sales-pipeline"
# qualifier <-> outreach:
pilotctl --json handshake <prefix>-outreach "setup: sales-pipeline"
pilotctl --json handshake <prefix>-qualifier "setup: sales-pipeline"
# outreach <-> crm-sync:
pilotctl --json handshake <prefix>-crm-sync "setup: sales-pipeline"
pilotctl --json handshake <prefix>-outreach "setup: sales-pipeline"
```

## Workflow Example

```bash
# On qualifier — subscribe to raw leads:
pilotctl --json subscribe <prefix>-prospector raw-lead
# On outreach — subscribe to qualified leads:
pilotctl --json subscribe <prefix>-qualifier qualified-lead
# On crm-sync — subscribe to engagement events:
pilotctl --json subscribe <prefix>-outreach engagement-event
# On prospector — publish a lead:
pilotctl --json publish <prefix>-qualifier raw-lead '{"company":"Initech","source":"linkedin","fit_score":82}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
