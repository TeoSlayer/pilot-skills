---
name: pilot-supply-chain-orchestrator-setup
description: >
  Deploy a supply chain orchestration pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up coordinated inventory, logistics, procurement, and compliance agents
  2. User is configuring warehouse management with automated reorder workflows
  3. User asks about supply chain automation, procurement pipelines, or shipping compliance

  Do NOT use this skill when:
  - User wants a single inventory dashboard (use pilot-metrics instead)
  - User wants to send a one-off alert for low stock (use pilot-alert instead)
  - User only needs webhook integration with a supplier API (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - supply-chain
  - logistics
  - procurement
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

# Supply Chain Orchestrator Setup

Deploy 4 agents: inventory, routing, procurement, and compliance.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| inventory | `<prefix>-inventory` | pilot-metrics, pilot-cron, pilot-alert, pilot-stream-data | Monitors stock levels, predicts demand, triggers reorders |
| routing | `<prefix>-routing` | pilot-task-router, pilot-stream-data, pilot-receipt | Optimizes delivery routes, manages fleet assignments |
| procurement | `<prefix>-procurement` | pilot-webhook-bridge, pilot-audit-log, pilot-escrow | Manages suppliers, places purchase orders |
| compliance | `<prefix>-compliance` | pilot-audit-log, pilot-event-filter, pilot-alert | Validates regulatory compliance, maintains audit trails |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For inventory:
clawhub install pilot-metrics pilot-cron pilot-alert pilot-stream-data
# For routing:
clawhub install pilot-task-router pilot-stream-data pilot-receipt
# For procurement:
clawhub install pilot-webhook-bridge pilot-audit-log pilot-escrow
# For compliance:
clawhub install pilot-audit-log pilot-event-filter pilot-alert
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/supply-chain-orchestrator.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

## Manifest Templates Per Role

### inventory
```json
{
  "setup": "supply-chain-orchestrator", "role": "inventory", "role_name": "Inventory Manager",
  "hostname": "<prefix>-inventory",
  "skills": {
    "pilot-metrics": "Track stock levels, turnover rates, and demand forecasts.",
    "pilot-cron": "Run scheduled inventory audits and demand recalculations.",
    "pilot-alert": "Emit reorder alerts when stock falls below safety thresholds.",
    "pilot-stream-data": "Stream real-time warehouse activity to downstream agents."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-procurement", "port": 1002, "topic": "reorder-request", "description": "Reorder requests when stock is low" },
    { "direction": "send", "peer": "<prefix>-routing", "port": 1002, "topic": "fulfillment-order", "description": "Fulfillment orders for customer deliveries" },
    { "direction": "receive", "peer": "<prefix>-compliance", "port": 1002, "topic": "compliance-clearance", "description": "Clearance to release held stock" }
  ],
  "handshakes_needed": ["<prefix>-procurement", "<prefix>-routing", "<prefix>-compliance"]
}
```

### routing
```json
{
  "setup": "supply-chain-orchestrator", "role": "routing", "role_name": "Logistics Router",
  "hostname": "<prefix>-routing",
  "skills": {
    "pilot-task-router": "Assign shipments to carriers based on cost, speed, and capacity.",
    "pilot-stream-data": "Stream shipment tracking updates in real time.",
    "pilot-receipt": "Generate delivery confirmations and proof-of-delivery receipts."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-inventory", "port": 1002, "topic": "fulfillment-order", "description": "Fulfillment orders to route" },
    { "direction": "send", "peer": "<prefix>-compliance", "port": 1002, "topic": "shipping-manifest", "description": "Shipping manifests for regulatory review" }
  ],
  "handshakes_needed": ["<prefix>-inventory", "<prefix>-compliance"]
}
```

### procurement
```json
{
  "setup": "supply-chain-orchestrator", "role": "procurement", "role_name": "Procurement Agent",
  "hostname": "<prefix>-procurement",
  "skills": {
    "pilot-webhook-bridge": "Interface with supplier APIs for quotes and order placement.",
    "pilot-audit-log": "Log all procurement decisions, bids, and purchase orders.",
    "pilot-escrow": "Hold funds in escrow until delivery confirmation."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-inventory", "port": 1002, "topic": "reorder-request", "description": "Reorder requests from inventory" },
    { "direction": "send", "peer": "<prefix>-compliance", "port": 1002, "topic": "purchase-order", "description": "Purchase orders for compliance validation" }
  ],
  "handshakes_needed": ["<prefix>-inventory", "<prefix>-compliance"]
}
```

### compliance
```json
{
  "setup": "supply-chain-orchestrator", "role": "compliance", "role_name": "Compliance Checker",
  "hostname": "<prefix>-compliance",
  "skills": {
    "pilot-audit-log": "Maintain immutable audit trail of all compliance decisions.",
    "pilot-event-filter": "Filter and classify events by regulatory category.",
    "pilot-alert": "Flag compliance violations and emit escalation alerts."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-procurement", "port": 1002, "topic": "purchase-order", "description": "Purchase orders to validate" },
    { "direction": "receive", "peer": "<prefix>-routing", "port": 1002, "topic": "shipping-manifest", "description": "Shipping manifests to check" },
    { "direction": "send", "peer": "<prefix>-inventory", "port": 1002, "topic": "compliance-clearance", "description": "Clearance to release goods" }
  ],
  "handshakes_needed": ["<prefix>-procurement", "<prefix>-routing", "<prefix>-inventory"]
}
```

## Data Flows

- `inventory -> procurement` : reorder requests when stock drops below threshold (port 1002)
- `inventory -> routing` : fulfillment orders for customer deliveries (port 1002)
- `procurement -> compliance` : purchase orders requiring regulatory validation (port 1002)
- `routing -> compliance` : shipping manifests for export/import checks (port 1002)
- `compliance -> inventory` : compliance clearance to release held stock (port 1002)

## Workflow Example

```bash
# On inventory -- low stock triggers reorder:
pilotctl --json publish <prefix>-procurement reorder-request '{"sku":"WH-4821","warehouse":"us-east-1","current_qty":12,"reorder_point":50,"suggested_qty":200}'
# On procurement -- place PO after supplier selection:
pilotctl --json publish <prefix>-compliance purchase-order '{"po_id":"PO-9934","supplier":"GlobalParts Inc","sku":"WH-4821","qty":200,"unit_price":14.50}'
# On inventory -- ship customer order:
pilotctl --json publish <prefix>-routing fulfillment-order '{"order_id":"ORD-77201","sku":"WH-4821","qty":5,"dest_zip":"94105"}'
# On routing -- submit manifest:
pilotctl --json publish <prefix>-compliance shipping-manifest '{"manifest_id":"SHP-3301","carrier":"FedEx","items":[{"sku":"WH-4821","qty":5}]}'
# On compliance -- approve:
pilotctl --json publish <prefix>-inventory compliance-clearance '{"ref_id":"PO-9934","status":"approved"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
