---
name: pilot-inventory-management-setup
description: >
  Deploy an inventory management system with 3 agents.

  Use this skill when:
  1. User wants to set up an automated inventory management system
  2. User is configuring an agent as part of a stock tracking workflow
  3. User asks about automating warehouse inventory and reorder processes

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants a one-off alert notification (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - inventory
  - warehouse
  - supply-chain
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

# Inventory Management Setup

Deploy 3 agents that automate inventory tracking from stock monitoring to reorder alerts.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| tracker | `<prefix>-tracker` | pilot-metrics, pilot-stream-data, pilot-audit-log | Monitors stock levels, tracks shipments, updates quantities |
| forecaster | `<prefix>-forecaster` | pilot-dataset, pilot-task-router, pilot-cron | Analyzes sales trends and predicts stock needs |
| alerter | `<prefix>-alerter` | pilot-alert, pilot-webhook-bridge, pilot-slack-bridge | Triggers reorder notifications and sends PO requests |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For tracker:
clawhub install pilot-metrics pilot-stream-data pilot-audit-log

# For forecaster:
clawhub install pilot-dataset pilot-task-router pilot-cron

# For alerter:
clawhub install pilot-alert pilot-webhook-bridge pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/inventory-management.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### tracker
```json
{
  "setup": "inventory-management", "setup_name": "Inventory Management",
  "role": "tracker", "role_name": "Stock Tracker",
  "hostname": "<prefix>-tracker",
  "description": "Monitors warehouse stock levels, tracks incoming/outgoing shipments, and updates quantities in real time.",
  "skills": {
    "pilot-metrics": "Collect and expose real-time stock level metrics and movement rates.",
    "pilot-stream-data": "Stream live inventory updates as shipments arrive and orders ship.",
    "pilot-audit-log": "Log all stock movements for compliance and audit trail."
  },
  "peers": [{"role": "forecaster", "hostname": "<prefix>-forecaster", "description": "Receives stock snapshots for demand analysis"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-forecaster", "port": 1002, "topic": "stock-snapshot", "description": "Stock snapshots with quantities and movement history"}],
  "handshakes_needed": ["<prefix>-forecaster"]
}
```

### forecaster
```json
{
  "setup": "inventory-management", "setup_name": "Inventory Management",
  "role": "forecaster", "role_name": "Demand Forecaster",
  "hostname": "<prefix>-forecaster",
  "description": "Analyzes sales trends, seasonal patterns, and lead times to predict stock needs.",
  "skills": {
    "pilot-dataset": "Load and analyze historical sales data and seasonal patterns.",
    "pilot-task-router": "Route incoming stock snapshots to the appropriate forecasting model.",
    "pilot-cron": "Schedule recurring demand forecast runs on daily and weekly cadences."
  },
  "peers": [
    {"role": "tracker", "hostname": "<prefix>-tracker", "description": "Sends stock snapshots with current levels"},
    {"role": "alerter", "hostname": "<prefix>-alerter", "description": "Receives reorder forecasts for threshold alerting"}
  ],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-tracker", "port": 1002, "topic": "stock-snapshot", "description": "Stock snapshots with quantities and movement history"},
    {"direction": "send", "peer": "<prefix>-alerter", "port": 1002, "topic": "reorder-forecast", "description": "Reorder forecasts with quantities and urgency scores"}
  ],
  "handshakes_needed": ["<prefix>-tracker", "<prefix>-alerter"]
}
```

### alerter
```json
{
  "setup": "inventory-management", "setup_name": "Inventory Management",
  "role": "alerter", "role_name": "Reorder Alerter",
  "hostname": "<prefix>-alerter",
  "description": "Triggers reorder notifications when stock hits thresholds and sends PO requests to suppliers.",
  "skills": {
    "pilot-alert": "Evaluate stock levels against thresholds and fire reorder alerts.",
    "pilot-webhook-bridge": "Send purchase order requests to supplier systems via webhook.",
    "pilot-slack-bridge": "Notify procurement team in Slack when reorders are triggered."
  },
  "peers": [{"role": "forecaster", "hostname": "<prefix>-forecaster", "description": "Sends reorder forecasts with quantities and urgency"}],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-forecaster", "port": 1002, "topic": "reorder-forecast", "description": "Reorder forecasts with quantities and urgency scores"},
    {"direction": "send", "peer": "external", "port": 443, "topic": "purchase-order", "description": "Purchase order requests to suppliers"}
  ],
  "handshakes_needed": ["<prefix>-forecaster"]
}
```

## Data Flows

- `tracker -> forecaster` : stock-snapshot (port 1002)
- `forecaster -> alerter` : reorder-forecast (port 1002)
- `alerter -> external` : purchase-order via webhook (port 443)

## Handshakes

```bash
# tracker and forecaster handshake with each other:
pilotctl --json handshake <prefix>-forecaster "setup: inventory-management"
pilotctl --json handshake <prefix>-tracker "setup: inventory-management"

# forecaster and alerter handshake with each other:
pilotctl --json handshake <prefix>-alerter "setup: inventory-management"
pilotctl --json handshake <prefix>-forecaster "setup: inventory-management"
```

## Workflow Example

```bash
# On forecaster -- subscribe to stock snapshots:
pilotctl --json subscribe <prefix>-tracker stock-snapshot

# On alerter -- subscribe to reorder forecasts:
pilotctl --json subscribe <prefix>-forecaster reorder-forecast

# On tracker -- publish a stock snapshot:
pilotctl --json publish <prefix>-forecaster stock-snapshot '{"warehouse":"us-east-1","sku":"WIDGET-A100","quantity_on_hand":142,"daily_velocity":12}'

# On forecaster -- publish reorder forecast to alerter:
pilotctl --json publish <prefix>-alerter reorder-forecast '{"sku":"WIDGET-A100","current_stock":142,"reorder_quantity":500,"urgency":"high"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
