# Supply Chain Orchestrator Setup

An end-to-end supply chain orchestration pipeline coordinating inventory management, logistics routing, procurement, and regulatory compliance across four specialized agents. The inventory manager monitors stock levels and predicts demand, triggering reorder flows that cascade through procurement for supplier negotiation, routing for delivery optimization, and compliance for regulatory validation before any goods move.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### inventory (Inventory Manager)
Monitors stock levels across warehouses, predicts demand using historical patterns and seasonal trends, triggers reorder alerts when safety stock thresholds are breached. Publishes fulfillment orders to routing when customer orders arrive.

**Skills:** pilot-metrics, pilot-cron, pilot-alert, pilot-stream-data

### routing (Logistics Router)
Optimizes delivery routes based on real-time conditions, manages fleet assignments, and tracks shipment status. Considers carrier capacity, transit times, and cost constraints. Generates shipping manifests for compliance review.

**Skills:** pilot-task-router, pilot-stream-data, pilot-receipt

### procurement (Procurement Agent)
Manages supplier relationships, compares quotes across vendors, places purchase orders, and tracks delivery timelines. Handles reorder requests from inventory by soliciting bids and selecting optimal suppliers based on price, lead time, and reliability score.

**Skills:** pilot-webhook-bridge, pilot-audit-log, pilot-escrow

### compliance (Compliance Checker)
Validates all procurement and shipping operations against regulatory requirements -- import/export controls, hazardous materials handling, trade sanctions, and customs documentation. Flags violations and maintains a complete audit trail. Issues compliance clearance before goods can ship.

**Skills:** pilot-audit-log, pilot-event-filter, pilot-alert

## Data Flow

```
inventory   --> procurement : Reorder requests when stock drops below threshold (port 1002)
inventory   --> routing     : Fulfillment orders for customer deliveries (port 1002)
procurement --> compliance  : Purchase orders requiring regulatory validation (port 1002)
routing     --> compliance  : Shipping manifests for export/import checks (port 1002)
compliance  --> inventory   : Compliance clearance to release held stock (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On inventory warehouse server
clawhub install pilot-metrics pilot-cron pilot-alert pilot-stream-data
pilotctl set-hostname <your-prefix>-inventory

# On logistics routing server
clawhub install pilot-task-router pilot-stream-data pilot-receipt
pilotctl set-hostname <your-prefix>-routing

# On procurement server
clawhub install pilot-webhook-bridge pilot-audit-log pilot-escrow
pilotctl set-hostname <your-prefix>-procurement

# On compliance server
clawhub install pilot-audit-log pilot-event-filter pilot-alert
pilotctl set-hostname <your-prefix>-compliance
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# inventory <-> procurement (reorder requests)
# On inventory:
pilotctl handshake <your-prefix>-procurement "setup: supply-chain-orchestrator"
# On procurement:
pilotctl handshake <your-prefix>-inventory "setup: supply-chain-orchestrator"

# inventory <-> routing (fulfillment orders)
# On inventory:
pilotctl handshake <your-prefix>-routing "setup: supply-chain-orchestrator"
# On routing:
pilotctl handshake <your-prefix>-inventory "setup: supply-chain-orchestrator"

# procurement <-> compliance (purchase orders)
# On procurement:
pilotctl handshake <your-prefix>-compliance "setup: supply-chain-orchestrator"
# On compliance:
pilotctl handshake <your-prefix>-procurement "setup: supply-chain-orchestrator"

# routing <-> compliance (shipping manifests)
# On routing:
pilotctl handshake <your-prefix>-compliance "setup: supply-chain-orchestrator"
# On compliance:
pilotctl handshake <your-prefix>-routing "setup: supply-chain-orchestrator"

# compliance <-> inventory (compliance clearance)
# On compliance:
pilotctl handshake <your-prefix>-inventory "setup: supply-chain-orchestrator"
# On inventory:
pilotctl handshake <your-prefix>-compliance "setup: supply-chain-orchestrator"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-inventory -- trigger a reorder when stock is low:
pilotctl publish <your-prefix>-procurement reorder-request '{"sku":"WH-4821","warehouse":"us-east-1","current_qty":12,"reorder_point":50,"suggested_qty":200}'

# On <your-prefix>-procurement -- place a purchase order after selecting supplier:
pilotctl publish <your-prefix>-compliance purchase-order '{"po_id":"PO-9934","supplier":"GlobalParts Inc","sku":"WH-4821","qty":200,"unit_price":14.50,"currency":"USD","origin_country":"CN"}'

# On <your-prefix>-inventory -- create a fulfillment order:
pilotctl publish <your-prefix>-routing fulfillment-order '{"order_id":"ORD-77201","sku":"WH-4821","qty":5,"dest_zip":"94105","priority":"standard"}'

# On <your-prefix>-routing -- submit shipping manifest for compliance:
pilotctl publish <your-prefix>-compliance shipping-manifest '{"manifest_id":"SHP-3301","carrier":"FedEx","origin":"us-east-1","dest":"94105","items":[{"sku":"WH-4821","qty":5,"weight_kg":2.3}]}'

# On <your-prefix>-compliance -- issue clearance:
pilotctl publish <your-prefix>-inventory compliance-clearance '{"ref_id":"PO-9934","status":"approved","notes":"No restricted items, customs docs generated"}'
```
