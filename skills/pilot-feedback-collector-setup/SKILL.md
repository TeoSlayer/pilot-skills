---
name: pilot-feedback-collector-setup
description: >
  Deploy a feedback collection pipeline with 3 agents that automate intake,
  sentiment analysis, and actionable routing.

  Use this skill when:
  1. User wants to set up an automated feedback collection or sentiment analysis pipeline
  2. User is configuring an agent as part of a customer feedback workflow
  3. User asks about routing NPS, survey, or support ticket feedback to teams

  Do NOT use this skill when:
  - User wants a simple chat interface (use pilot-chat instead)
  - User wants a one-off alert notification (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - feedback
  - sentiment
  - customer-experience
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

# Feedback Collector Setup

Deploy 3 agents that automate feedback intake, sentiment analysis, and actionable routing.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| intake | `<prefix>-intake` | pilot-stream-data, pilot-chat, pilot-archive | Collects feedback from surveys, NPS, app reviews, support tickets |
| analyzer | `<prefix>-analyzer` | pilot-event-filter, pilot-metrics, pilot-task-router | Scores sentiment, extracts themes, identifies trends |
| router | `<prefix>-router` | pilot-alert, pilot-slack-bridge, pilot-webhook-bridge | Routes actionable feedback to product, engineering, or support |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For intake:
clawhub install pilot-stream-data pilot-chat pilot-archive

# For analyzer:
clawhub install pilot-event-filter pilot-metrics pilot-task-router

# For router:
clawhub install pilot-alert pilot-slack-bridge pilot-webhook-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/feedback-collector.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### intake
```json
{"setup":"feedback-collector","setup_name":"Feedback Collector","role":"intake","role_name":"Feedback Intake","hostname":"<prefix>-intake","description":"Collects feedback from surveys, NPS forms, app reviews, and support tickets. Normalizes into consistent format.","skills":{"pilot-stream-data":"Stream incoming feedback from multiple sources in real time.","pilot-chat":"Accept free-form feedback via conversational interface.","pilot-archive":"Archive raw feedback submissions for audit and reprocessing."},"peers":[{"role":"analyzer","hostname":"<prefix>-analyzer","description":"Receives normalized feedback for sentiment analysis"}],"data_flows":[{"direction":"send","peer":"<prefix>-analyzer","port":1002,"topic":"raw-feedback","description":"Raw feedback normalized from all sources"}],"handshakes_needed":["<prefix>-analyzer"]}
```

### analyzer
```json
{"setup":"feedback-collector","setup_name":"Feedback Collector","role":"analyzer","role_name":"Sentiment Analyzer","hostname":"<prefix>-analyzer","description":"Scores sentiment, extracts themes, identifies trending complaints and praise.","skills":{"pilot-event-filter":"Filter feedback by sentiment threshold and priority level.","pilot-metrics":"Track sentiment trends, theme frequency, and NPS distribution.","pilot-task-router":"Route feedback to specialized analysis by source type."},"peers":[{"role":"intake","hostname":"<prefix>-intake","description":"Sends raw feedback for analysis"},{"role":"router","hostname":"<prefix>-router","description":"Receives scored feedback for team routing"}],"data_flows":[{"direction":"receive","peer":"<prefix>-intake","port":1002,"topic":"raw-feedback","description":"Raw feedback normalized from all sources"},{"direction":"send","peer":"<prefix>-router","port":1002,"topic":"scored-feedback","description":"Scored feedback with sentiment and themes"}],"handshakes_needed":["<prefix>-intake","<prefix>-router"]}
```

### router
```json
{"setup":"feedback-collector","setup_name":"Feedback Collector","role":"router","role_name":"Feedback Router","hostname":"<prefix>-router","description":"Routes actionable feedback to product, engineering, or support teams via Slack and webhook.","skills":{"pilot-alert":"Escalate critical feedback issues that require immediate attention.","pilot-slack-bridge":"Post feedback summaries and alerts to team-specific Slack channels.","pilot-webhook-bridge":"Push feedback events to external ticketing and analytics systems."},"peers":[{"role":"analyzer","hostname":"<prefix>-analyzer","description":"Sends scored feedback for team routing"}],"data_flows":[{"direction":"receive","peer":"<prefix>-analyzer","port":1002,"topic":"scored-feedback","description":"Scored feedback with sentiment and themes"},{"direction":"send","peer":"external","port":443,"topic":"feedback-alert","description":"Feedback alerts to product, engineering, support"}],"handshakes_needed":["<prefix>-analyzer"]}
```

## Data Flows

- `intake -> analyzer` : raw-feedback events (port 1002)
- `analyzer -> router` : scored-feedback events (port 1002)
- `router -> external` : feedback-alert via webhook (port 443)

## Handshakes

```bash
# intake <-> analyzer:
pilotctl --json handshake <prefix>-analyzer "setup: feedback-collector"
pilotctl --json handshake <prefix>-intake "setup: feedback-collector"
# analyzer <-> router:
pilotctl --json handshake <prefix>-router "setup: feedback-collector"
pilotctl --json handshake <prefix>-analyzer "setup: feedback-collector"
```

## Workflow Example

```bash
# On analyzer -- subscribe to raw feedback:
pilotctl --json subscribe <prefix>-intake raw-feedback
# On router -- subscribe to scored feedback:
pilotctl --json subscribe <prefix>-analyzer scored-feedback
# On intake -- publish raw feedback:
pilotctl --json publish <prefix>-analyzer raw-feedback '{"source":"nps_survey","score":3,"customer":"user-8291","text":"Dashboard navigation is confusing."}'
# On analyzer -- publish scored feedback:
pilotctl --json publish <prefix>-router scored-feedback '{"sentiment":-0.6,"themes":["ux","navigation"],"priority":"high","trending":true}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
