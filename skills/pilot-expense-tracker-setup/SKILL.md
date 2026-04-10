---
name: pilot-expense-tracker-setup
description: >
  Deploy an expense tracking pipeline with 3 agents that automate receipt
  collection, categorization, and report generation.

  Use this skill when:
  1. User wants to set up an automated expense tracking or receipt processing pipeline
  2. User is configuring an agent as part of an expense management workflow
  3. User asks about automating receipt-to-report expense workflows

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants a one-off webhook notification (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - expense
  - finance
  - receipts
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

# Expense Tracker Setup

Deploy 3 agents that automate expense receipt collection, categorization, and report generation.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| collector | `<prefix>-collector` | pilot-stream-data, pilot-share, pilot-archive | Accepts receipts, extracts amount, vendor, category |
| categorizer | `<prefix>-categorizer` | pilot-task-router, pilot-event-filter, pilot-metrics | Classifies expenses, flags policy violations, calculates totals |
| reporter | `<prefix>-reporter` | pilot-webhook-bridge, pilot-announce, pilot-slack-bridge | Generates reports, submits for approval, notifies managers |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For collector:
clawhub install pilot-stream-data pilot-share pilot-archive

# For categorizer:
clawhub install pilot-task-router pilot-event-filter pilot-metrics

# For reporter:
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/expense-tracker.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### collector
```json
{"setup":"expense-tracker","setup_name":"Expense Tracker","role":"collector","role_name":"Receipt Collector","hostname":"<prefix>-collector","description":"Accepts expense receipts via photo upload or email forward. Extracts amount, vendor, and category.","skills":{"pilot-stream-data":"Stream receipt images and email attachments to the categorizer.","pilot-share":"Share extracted receipt data with downstream agents.","pilot-archive":"Archive original receipts for audit and compliance."},"peers":[{"role":"categorizer","hostname":"<prefix>-categorizer","description":"Receives raw expenses for classification"}],"data_flows":[{"direction":"send","peer":"<prefix>-categorizer","port":1002,"topic":"raw-expense","description":"Raw expense data with amount, vendor, category"}],"handshakes_needed":["<prefix>-categorizer"]}
```

### categorizer
```json
{"setup":"expense-tracker","setup_name":"Expense Tracker","role":"categorizer","role_name":"Expense Categorizer","hostname":"<prefix>-categorizer","description":"Classifies expenses by category, flags policy violations, calculates totals by period.","skills":{"pilot-task-router":"Route expenses to category-specific classification rules.","pilot-event-filter":"Filter and flag expenses that violate spending policies.","pilot-metrics":"Track spending totals by category, employee, and period."},"peers":[{"role":"collector","hostname":"<prefix>-collector","description":"Sends raw expense data"},{"role":"reporter","hostname":"<prefix>-reporter","description":"Receives categorized expenses for reporting"}],"data_flows":[{"direction":"receive","peer":"<prefix>-collector","port":1002,"topic":"raw-expense","description":"Raw expense data with amount, vendor, category"},{"direction":"send","peer":"<prefix>-reporter","port":1002,"topic":"categorized-expense","description":"Categorized expense with compliance flags"}],"handshakes_needed":["<prefix>-collector","<prefix>-reporter"]}
```

### reporter
```json
{"setup":"expense-tracker","setup_name":"Expense Tracker","role":"reporter","role_name":"Expense Reporter","hostname":"<prefix>-reporter","description":"Generates expense reports, submits for approval, notifies managers via Slack.","skills":{"pilot-webhook-bridge":"Submit completed expense reports to approval systems via webhook.","pilot-announce":"Broadcast report submission events to finance team.","pilot-slack-bridge":"Notify managers of pending expense approvals in Slack."},"peers":[{"role":"categorizer","hostname":"<prefix>-categorizer","description":"Sends categorized expenses for report generation"}],"data_flows":[{"direction":"receive","peer":"<prefix>-categorizer","port":1002,"topic":"categorized-expense","description":"Categorized expense with compliance flags"},{"direction":"send","peer":"external","port":443,"topic":"expense-report","description":"Expense report submitted for approval"}],"handshakes_needed":["<prefix>-categorizer"]}
```

## Data Flows

- `collector -> categorizer` : raw-expense events (port 1002)
- `categorizer -> reporter` : categorized-expense events (port 1002)
- `reporter -> external` : expense-report via webhook (port 443)

## Handshakes

```bash
# collector <-> categorizer:
pilotctl --json handshake <prefix>-categorizer "setup: expense-tracker"
pilotctl --json handshake <prefix>-collector "setup: expense-tracker"
# categorizer <-> reporter:
pilotctl --json handshake <prefix>-reporter "setup: expense-tracker"
pilotctl --json handshake <prefix>-categorizer "setup: expense-tracker"
```

## Workflow Example

```bash
# On categorizer -- subscribe to raw expenses:
pilotctl --json subscribe <prefix>-collector raw-expense
# On reporter -- subscribe to categorized expenses:
pilotctl --json subscribe <prefix>-categorizer categorized-expense
# On collector -- publish a raw expense:
pilotctl --json publish <prefix>-categorizer raw-expense '{"vendor":"Delta Airlines","amount":487.50,"currency":"USD","date":"2025-03-12","receipt_type":"photo","employee":"jane.smith"}'
# On categorizer -- publish categorized expense:
pilotctl --json publish <prefix>-reporter categorized-expense '{"vendor":"Delta Airlines","amount":487.50,"category":"travel","policy_compliant":true,"period":"2025-Q1"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
