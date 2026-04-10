# E-Commerce Ops

Deploy a multi-agent e-commerce operations system that manages product catalogs, processes orders, tracks inventory, and handles customer support. Each agent owns a distinct domain of the storefront, communicating through event streams to keep the entire operation synchronized in real time.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### catalog-manager (Product Catalog Manager)
Manages product listings, prices, descriptions, and images. Publishes catalog updates.

**Skills:** pilot-dataset, pilot-share, pilot-audit-log

### order-processor (Order Processor)
Receives and validates orders, calculates totals, triggers fulfillment.

**Skills:** pilot-task-router, pilot-receipt, pilot-escrow

### inventory-tracker (Inventory Tracker)
Monitors stock levels, triggers reorder alerts, syncs warehouse counts.

**Skills:** pilot-metrics, pilot-alert, pilot-stream-data

### support-bot (Customer Support Bot)
Handles order inquiries, returns, refund requests, and FAQs.

**Skills:** pilot-chat, pilot-event-filter, pilot-webhook-bridge

## Data Flow

```
catalog-manager   --> order-processor   : Catalog updates with pricing changes (port 1002)
order-processor   --> inventory-tracker : Order fulfilled events for stock deduction (port 1002)
inventory-tracker --> catalog-manager   : Stock alerts for out-of-stock flagging (port 1002)
order-processor   --> support-bot       : Order status updates for customer queries (port 1002)
support-bot       --> external          : Support escalations via webhook (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (product catalog)
clawhub install pilot-dataset pilot-share pilot-audit-log
pilotctl set-hostname <your-prefix>-catalog-manager

# On server 2 (order processing)
clawhub install pilot-task-router pilot-receipt pilot-escrow
pilotctl set-hostname <your-prefix>-order-processor

# On server 3 (inventory tracking)
clawhub install pilot-metrics pilot-alert pilot-stream-data
pilotctl set-hostname <your-prefix>-inventory-tracker

# On server 4 (customer support)
clawhub install pilot-chat pilot-event-filter pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-support-bot
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On catalog-manager:
pilotctl handshake <your-prefix>-order-processor "setup: e-commerce-ops"
# On order-processor:
pilotctl handshake <your-prefix>-catalog-manager "setup: e-commerce-ops"
# On order-processor:
pilotctl handshake <your-prefix>-inventory-tracker "setup: e-commerce-ops"
# On inventory-tracker:
pilotctl handshake <your-prefix>-order-processor "setup: e-commerce-ops"
# On inventory-tracker:
pilotctl handshake <your-prefix>-catalog-manager "setup: e-commerce-ops"
# On catalog-manager:
pilotctl handshake <your-prefix>-inventory-tracker "setup: e-commerce-ops"
# On order-processor:
pilotctl handshake <your-prefix>-support-bot "setup: e-commerce-ops"
# On support-bot:
pilotctl handshake <your-prefix>-order-processor "setup: e-commerce-ops"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-order-processor — subscribe to catalog updates:
pilotctl subscribe <your-prefix>-catalog-manager catalog-update

# On <your-prefix>-inventory-tracker — subscribe to order events:
pilotctl subscribe <your-prefix>-order-processor order-fulfilled

# On <your-prefix>-catalog-manager — subscribe to stock alerts:
pilotctl subscribe <your-prefix>-inventory-tracker stock-alert

# On <your-prefix>-support-bot — subscribe to order status:
pilotctl subscribe <your-prefix>-order-processor order-status

# On <your-prefix>-catalog-manager — publish a catalog update:
pilotctl publish <your-prefix>-order-processor catalog-update '{"product_id":"SKU-4821","name":"Wireless Headphones","price":79.99,"action":"price_change","old_price":99.99}'

# On <your-prefix>-order-processor — publish an order fulfilled event:
pilotctl publish <your-prefix>-inventory-tracker order-fulfilled '{"order_id":"ORD-10042","product_id":"SKU-4821","quantity":2,"total":159.98,"status":"fulfilled"}'

# On <your-prefix>-inventory-tracker — publish a stock alert:
pilotctl publish <your-prefix>-catalog-manager stock-alert '{"product_id":"SKU-4821","current_stock":3,"reorder_threshold":10,"status":"low_stock"}'

# On <your-prefix>-order-processor — publish order status to support:
pilotctl publish <your-prefix>-support-bot order-status '{"order_id":"ORD-10042","customer":"alice@example.com","status":"shipped","tracking":"1Z999AA10123456784"}'
```
