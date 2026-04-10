---
name: pilot-e-commerce-ops-setup
description: >
  Deploy an e-commerce operations system with 4 agents for catalog, orders, inventory, and support.

  Use this skill when:
  1. User wants to set up e-commerce or online store operations
  2. User is configuring an agent as part of an e-commerce automation setup
  3. User asks about product catalogs, order processing, inventory tracking, or support bots across agents

  Do NOT use this skill when:
  - User wants a single dataset operation (use pilot-dataset instead)
  - User wants to send a one-off receipt (use pilot-receipt instead)
tags:
  - pilot-protocol
  - setup
  - e-commerce
  - operations
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

# E-Commerce Ops Setup

Deploy 4 agents that manage product catalogs, process orders, track inventory, and handle customer support.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| catalog-manager | `<prefix>-catalog-manager` | pilot-dataset, pilot-share, pilot-audit-log | Manages product listings, publishes catalog updates |
| order-processor | `<prefix>-order-processor` | pilot-task-router, pilot-receipt, pilot-escrow | Validates orders, calculates totals, triggers fulfillment |
| inventory-tracker | `<prefix>-inventory-tracker` | pilot-metrics, pilot-alert, pilot-stream-data | Monitors stock levels, triggers reorder alerts |
| support-bot | `<prefix>-support-bot` | pilot-chat, pilot-event-filter, pilot-webhook-bridge | Handles inquiries, returns, refund requests |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For catalog-manager:
clawhub install pilot-dataset pilot-share pilot-audit-log
# For order-processor:
clawhub install pilot-task-router pilot-receipt pilot-escrow
# For inventory-tracker:
clawhub install pilot-metrics pilot-alert pilot-stream-data
# For support-bot:
clawhub install pilot-chat pilot-event-filter pilot-webhook-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/e-commerce-ops.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### catalog-manager
```json
{
  "setup": "e-commerce-ops", "setup_name": "E-Commerce Ops",
  "role": "catalog-manager", "role_name": "Product Catalog Manager",
  "hostname": "<prefix>-catalog-manager",
  "description": "Manages product listings, prices, descriptions, and images. Publishes catalog updates.",
  "skills": {"pilot-dataset": "Store and serve product catalog data.", "pilot-share": "Publish catalog updates to order-processor.", "pilot-audit-log": "Log all catalog changes for compliance."},
  "peers": [{"role": "order-processor", "hostname": "<prefix>-order-processor", "description": "Receives catalog updates"}, {"role": "inventory-tracker", "hostname": "<prefix>-inventory-tracker", "description": "Sends stock alerts for catalog flagging"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-order-processor", "port": 1002, "topic": "catalog-update", "description": "Catalog updates with pricing changes"}, {"direction": "receive", "peer": "<prefix>-inventory-tracker", "port": 1002, "topic": "stock-alert", "description": "Stock alerts for out-of-stock flagging"}],
  "handshakes_needed": ["<prefix>-order-processor", "<prefix>-inventory-tracker"]
}
```

### order-processor
```json
{
  "setup": "e-commerce-ops", "setup_name": "E-Commerce Ops",
  "role": "order-processor", "role_name": "Order Processor",
  "hostname": "<prefix>-order-processor",
  "description": "Receives and validates orders, calculates totals, triggers fulfillment.",
  "skills": {"pilot-task-router": "Route orders to fulfillment based on product type and warehouse.", "pilot-receipt": "Generate order confirmations and receipts.", "pilot-escrow": "Hold payment until order is confirmed fulfilled."},
  "peers": [{"role": "catalog-manager", "hostname": "<prefix>-catalog-manager", "description": "Sends catalog updates"}, {"role": "inventory-tracker", "hostname": "<prefix>-inventory-tracker", "description": "Receives fulfillment events"}, {"role": "support-bot", "hostname": "<prefix>-support-bot", "description": "Receives order status updates"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-catalog-manager", "port": 1002, "topic": "catalog-update", "description": "Catalog updates with pricing changes"}, {"direction": "send", "peer": "<prefix>-inventory-tracker", "port": 1002, "topic": "order-fulfilled", "description": "Order fulfilled events for stock deduction"}, {"direction": "send", "peer": "<prefix>-support-bot", "port": 1002, "topic": "order-status", "description": "Order status updates for customer queries"}],
  "handshakes_needed": ["<prefix>-catalog-manager", "<prefix>-inventory-tracker", "<prefix>-support-bot"]
}
```

### inventory-tracker
```json
{
  "setup": "e-commerce-ops", "setup_name": "E-Commerce Ops",
  "role": "inventory-tracker", "role_name": "Inventory Tracker",
  "hostname": "<prefix>-inventory-tracker",
  "description": "Monitors stock levels, triggers reorder alerts, syncs warehouse counts.",
  "skills": {"pilot-metrics": "Track stock levels, turnover rates, and warehouse utilization.", "pilot-alert": "Alert when stock drops below reorder thresholds.", "pilot-stream-data": "Stream inventory changes to catalog-manager."},
  "peers": [{"role": "order-processor", "hostname": "<prefix>-order-processor", "description": "Sends order fulfilled events"}, {"role": "catalog-manager", "hostname": "<prefix>-catalog-manager", "description": "Receives stock alerts"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-order-processor", "port": 1002, "topic": "order-fulfilled", "description": "Order fulfilled events for stock deduction"}, {"direction": "send", "peer": "<prefix>-catalog-manager", "port": 1002, "topic": "stock-alert", "description": "Stock alerts for out-of-stock flagging"}],
  "handshakes_needed": ["<prefix>-order-processor", "<prefix>-catalog-manager"]
}
```

### support-bot
```json
{
  "setup": "e-commerce-ops", "setup_name": "E-Commerce Ops",
  "role": "support-bot", "role_name": "Customer Support Bot",
  "hostname": "<prefix>-support-bot",
  "description": "Handles order inquiries, returns, refund requests, and FAQs.",
  "skills": {"pilot-chat": "Handle customer conversations about orders and returns.", "pilot-event-filter": "Filter and prioritize support tickets by severity.", "pilot-webhook-bridge": "Escalate unresolved issues to human agents via webhook."},
  "peers": [{"role": "order-processor", "hostname": "<prefix>-order-processor", "description": "Sends order status updates"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-order-processor", "port": 1002, "topic": "order-status", "description": "Order status updates for customer queries"}, {"direction": "send", "peer": "external", "port": 443, "topic": "support-escalation", "description": "Support escalations via webhook"}],
  "handshakes_needed": ["<prefix>-order-processor"]
}
```

## Data Flows

- `catalog-manager -> order-processor` : catalog-update events (port 1002)
- `order-processor -> inventory-tracker` : order-fulfilled events (port 1002)
- `inventory-tracker -> catalog-manager` : stock-alert events (port 1002)
- `order-processor -> support-bot` : order-status events (port 1002)
- `support-bot -> external` : support-escalation via webhook (port 443)

## Handshakes

```bash
# catalog-manager <-> order-processor:
pilotctl --json handshake <prefix>-order-processor "setup: e-commerce-ops"
pilotctl --json handshake <prefix>-catalog-manager "setup: e-commerce-ops"
# order-processor <-> inventory-tracker:
pilotctl --json handshake <prefix>-inventory-tracker "setup: e-commerce-ops"
pilotctl --json handshake <prefix>-order-processor "setup: e-commerce-ops"
# inventory-tracker <-> catalog-manager:
pilotctl --json handshake <prefix>-catalog-manager "setup: e-commerce-ops"
pilotctl --json handshake <prefix>-inventory-tracker "setup: e-commerce-ops"
# order-processor <-> support-bot:
pilotctl --json handshake <prefix>-support-bot "setup: e-commerce-ops"
pilotctl --json handshake <prefix>-order-processor "setup: e-commerce-ops"
```

## Workflow Example

```bash
# On order-processor — subscribe to catalog updates:
pilotctl --json subscribe <prefix>-catalog-manager catalog-update
# On inventory-tracker — subscribe to order events:
pilotctl --json subscribe <prefix>-order-processor order-fulfilled
# On catalog-manager — subscribe to stock alerts:
pilotctl --json subscribe <prefix>-inventory-tracker stock-alert
# On catalog-manager — publish a catalog update:
pilotctl --json publish <prefix>-order-processor catalog-update '{"product_id":"SKU-4821","name":"Wireless Headphones","price":79.99,"action":"price_change"}'
# On order-processor — publish an order fulfilled event:
pilotctl --json publish <prefix>-inventory-tracker order-fulfilled '{"order_id":"ORD-10042","product_id":"SKU-4821","quantity":2}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
