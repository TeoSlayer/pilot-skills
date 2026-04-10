---
name: pilot-customer-onboarding-setup
description: >
  Deploy a customer onboarding system with 3 agents that automate the
  new customer journey from welcome through setup to success tracking.

  Use this skill when:
  1. User wants to set up an automated customer onboarding pipeline
  2. User is configuring an agent as part of a customer success or onboarding workflow
  3. User asks about automating welcome sequences, setup guides, or adoption tracking across agents

  Do NOT use this skill when:
  - User wants a single chat interaction (use pilot-chat instead)
  - User wants a one-off alert notification (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - onboarding
  - customer-success
  - saas
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

# Customer Onboarding Setup

Deploy 3 agents that automate the customer journey from welcome through setup to success tracking.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| welcome-bot | `<prefix>-welcome-bot` | pilot-chat, pilot-announce, pilot-receipt | Greets customers, collects preferences, sends welcome sequences |
| setup-guide | `<prefix>-setup-guide` | pilot-task-chain, pilot-share, pilot-webhook-bridge | Walks through configuration, tracks milestones, offers help |
| success-tracker | `<prefix>-success-tracker` | pilot-metrics, pilot-alert, pilot-slack-bridge | Monitors adoption, identifies at-risk customers, triggers interventions |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# welcome-bot:
clawhub install pilot-chat pilot-announce pilot-receipt
# setup-guide:
clawhub install pilot-task-chain pilot-share pilot-webhook-bridge
# success-tracker:
clawhub install pilot-metrics pilot-alert pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/customer-onboarding.json << 'MANIFEST'
<USE ROLE TEMPLATE BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### welcome-bot
```json
{"setup":"customer-onboarding","setup_name":"Customer Onboarding","role":"welcome-bot","role_name":"Welcome Bot","hostname":"<prefix>-welcome-bot","description":"Greets new customers, collects preferences, sends personalized welcome sequences.","skills":{"pilot-chat":"Conduct interactive welcome conversations to gather customer preferences.","pilot-announce":"Broadcast new customer arrivals to internal teams.","pilot-receipt":"Confirm customer profile delivery to the setup guide."},"peers":[{"role":"setup-guide","hostname":"<prefix>-setup-guide","description":"Receives customer profiles for guided configuration"}],"data_flows":[{"direction":"send","peer":"<prefix>-setup-guide","port":1002,"topic":"customer-profile","description":"Customer profiles with preferences and onboarding path"}],"handshakes_needed":["<prefix>-setup-guide"]}
```

### setup-guide
```json
{"setup":"customer-onboarding","setup_name":"Customer Onboarding","role":"setup-guide","role_name":"Setup Guide","hostname":"<prefix>-setup-guide","description":"Walks customers through product configuration, checks completion milestones, offers help.","skills":{"pilot-task-chain":"Chain setup steps into sequential milestones with dependency tracking.","pilot-share":"Send onboarding progress data downstream to success tracker.","pilot-webhook-bridge":"Trigger external actions when milestones complete (e.g. provision resources)."},"peers":[{"role":"welcome-bot","hostname":"<prefix>-welcome-bot","description":"Sends customer profiles"},{"role":"success-tracker","hostname":"<prefix>-success-tracker","description":"Receives onboarding progress updates"}],"data_flows":[{"direction":"receive","peer":"<prefix>-welcome-bot","port":1002,"topic":"customer-profile","description":"Customer profiles with preferences and onboarding path"},{"direction":"send","peer":"<prefix>-success-tracker","port":1002,"topic":"onboarding-progress","description":"Onboarding progress with milestone completion data"}],"handshakes_needed":["<prefix>-welcome-bot","<prefix>-success-tracker"]}
```

### success-tracker
```json
{"setup":"customer-onboarding","setup_name":"Customer Onboarding","role":"success-tracker","role_name":"Success Tracker","hostname":"<prefix>-success-tracker","description":"Monitors adoption metrics, identifies at-risk customers, triggers intervention workflows.","skills":{"pilot-metrics":"Track adoption metrics — login frequency, feature usage, milestone completion rates.","pilot-alert":"Trigger alerts when customer health score drops below threshold.","pilot-slack-bridge":"Post customer health summaries and churn risk alerts to Slack."},"peers":[{"role":"setup-guide","hostname":"<prefix>-setup-guide","description":"Sends onboarding progress updates"}],"data_flows":[{"direction":"receive","peer":"<prefix>-setup-guide","port":1002,"topic":"onboarding-progress","description":"Onboarding progress with milestone completion data"},{"direction":"send","peer":"external","port":443,"topic":"health-report","description":"Customer health reports to dashboards and Slack"}],"handshakes_needed":["<prefix>-setup-guide"]}
```

## Data Flows

- `welcome-bot -> setup-guide` : customer-profile (port 1002)
- `setup-guide -> success-tracker` : onboarding-progress (port 1002)
- `success-tracker -> external` : health-report via webhook (port 443)

## Handshakes

```bash
# welcome-bot <-> setup-guide:
pilotctl --json handshake <prefix>-setup-guide "setup: customer-onboarding"
pilotctl --json handshake <prefix>-welcome-bot "setup: customer-onboarding"
# setup-guide <-> success-tracker:
pilotctl --json handshake <prefix>-success-tracker "setup: customer-onboarding"
pilotctl --json handshake <prefix>-setup-guide "setup: customer-onboarding"
```

## Workflow Example

```bash
# On setup-guide -- subscribe to customer profiles:
pilotctl --json subscribe <prefix>-welcome-bot customer-profile
# On success-tracker -- subscribe to onboarding progress:
pilotctl --json subscribe <prefix>-setup-guide onboarding-progress
# On welcome-bot -- publish a customer profile:
pilotctl --json publish <prefix>-setup-guide customer-profile '{"customer_id":"cust_8a3f","name":"Jane Smith","plan":"pro","preferences":{"goals":["integrations","reporting"]}}'
# On setup-guide -- publish onboarding progress:
pilotctl --json publish <prefix>-success-tracker onboarding-progress '{"customer_id":"cust_8a3f","completion":0.50,"milestones":{"account_created":true,"first_integration":true}}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
