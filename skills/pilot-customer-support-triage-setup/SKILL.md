---
name: pilot-customer-support-triage-setup
description: >
  Deploy a customer support triage system with 3 agents.

  Use this skill when:
  1. User wants to set up automated support ticket routing and triage
  2. User is configuring an agent as part of a customer support workflow
  3. User asks about automating ticket classification, resolution, or escalation

  Do NOT use this skill when:
  - User wants a single priority queue (use pilot-priority-queue instead)
  - User wants to send a one-off webhook (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - support
  - triage
  - customer-service
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

# Customer Support Triage Setup

Deploy 3 agents that classify, auto-resolve, and escalate support tickets.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| triage-bot | `<prefix>-triage-bot` | pilot-event-filter, pilot-priority-queue, pilot-task-router | Classifies tickets by urgency and routes to handler |
| resolver | `<prefix>-resolver` | pilot-task-router, pilot-receipt, pilot-audit-log | Auto-resolves routine queries from knowledge base |
| escalator | `<prefix>-escalator` | pilot-webhook-bridge, pilot-slack-bridge, pilot-alert | Enriches and escalates complex issues to humans |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For triage-bot:
clawhub install pilot-event-filter pilot-priority-queue pilot-task-router

# For resolver:
clawhub install pilot-task-router pilot-receipt pilot-audit-log

# For escalator:
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-alert
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/customer-support-triage.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### triage-bot
```json
{
  "setup": "customer-support-triage",
  "setup_name": "Customer Support Triage",
  "role": "triage-bot",
  "role_name": "Triage Bot",
  "hostname": "<prefix>-triage-bot",
  "description": "Receives incoming support tickets, classifies by urgency and category, routes to the right handler.",
  "skills": {
    "pilot-event-filter": "Filter and classify incoming tickets by urgency (low/medium/high/critical) and category (billing/technical/account).",
    "pilot-priority-queue": "Queue tickets by priority so critical issues are routed immediately.",
    "pilot-task-router": "Route classified tickets to resolver for routine issues or escalator for complex ones."
  },
  "peers": [
    { "role": "resolver", "hostname": "<prefix>-resolver", "description": "Handles routine tickets with knowledge base lookups" },
    { "role": "escalator", "hostname": "<prefix>-escalator", "description": "Handles complex tickets requiring human attention" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-resolver", "port": 1002, "topic": "ticket-routine", "description": "Routine tickets for automated resolution" },
    { "direction": "send", "peer": "<prefix>-escalator", "port": 1002, "topic": "ticket-complex", "description": "Complex tickets requiring human attention" }
  ],
  "handshakes_needed": ["<prefix>-resolver", "<prefix>-escalator"]
}
```

### resolver
```json
{
  "setup": "customer-support-triage",
  "setup_name": "Customer Support Triage",
  "role": "resolver",
  "role_name": "Auto-Resolver",
  "hostname": "<prefix>-resolver",
  "description": "Handles routine queries using knowledge base lookups -- order status, FAQs, password resets.",
  "skills": {
    "pilot-task-router": "Match incoming ticket category to the appropriate knowledge base article or resolution workflow.",
    "pilot-receipt": "Send resolution confirmation back to the triage bot for tracking.",
    "pilot-audit-log": "Log every auto-resolution with ticket ID, category, and resolution method for compliance."
  },
  "peers": [
    { "role": "triage-bot", "hostname": "<prefix>-triage-bot", "description": "Sends routine tickets for auto-resolution" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-triage-bot", "port": 1002, "topic": "ticket-routine", "description": "Routine tickets for automated resolution" }
  ],
  "handshakes_needed": ["<prefix>-triage-bot"]
}
```

### escalator
```json
{
  "setup": "customer-support-triage",
  "setup_name": "Customer Support Triage",
  "role": "escalator",
  "role_name": "Escalation Agent",
  "hostname": "<prefix>-escalator",
  "description": "Takes complex issues, enriches with customer history and context, forwards to human support via webhook or Slack.",
  "skills": {
    "pilot-webhook-bridge": "Forward enriched tickets to the helpdesk system (Zendesk, Freshdesk, etc.) via webhook.",
    "pilot-slack-bridge": "Post escalation summaries to the support team Slack channel with ticket context.",
    "pilot-alert": "Send urgent alerts for critical-priority tickets that need immediate human response."
  },
  "peers": [
    { "role": "triage-bot", "hostname": "<prefix>-triage-bot", "description": "Sends complex tickets that need human attention" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-triage-bot", "port": 1002, "topic": "ticket-complex", "description": "Complex tickets requiring human attention" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "escalation", "description": "Escalated tickets to helpdesk and Slack" }
  ],
  "handshakes_needed": ["<prefix>-triage-bot"]
}
```

## Data Flows

- `triage-bot -> resolver` : ticket-routine (port 1002)
- `triage-bot -> escalator` : ticket-complex (port 1002)
- `escalator -> external` : escalation via webhook (port 443)

## Handshakes

```bash
# triage-bot handshakes with resolver and escalator:
pilotctl --json handshake <prefix>-resolver "setup: customer-support-triage"
pilotctl --json handshake <prefix>-escalator "setup: customer-support-triage"

# resolver and escalator handshake back with triage-bot:
pilotctl --json handshake <prefix>-triage-bot "setup: customer-support-triage"
pilotctl --json handshake <prefix>-triage-bot "setup: customer-support-triage"
```

## Workflow Example

```bash
# On resolver -- subscribe to routine tickets:
pilotctl --json subscribe <prefix>-triage-bot ticket-routine

# On escalator -- subscribe to complex tickets:
pilotctl --json subscribe <prefix>-triage-bot ticket-complex

# On triage-bot -- route a routine ticket:
pilotctl --json publish <prefix>-resolver ticket-routine '{"ticket_id":"TK-4821","category":"account","urgency":"low","subject":"Password reset"}'

# On triage-bot -- route a complex ticket:
pilotctl --json publish <prefix>-escalator ticket-complex '{"ticket_id":"TK-4822","category":"technical","urgency":"critical","subject":"Data loss in production"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
