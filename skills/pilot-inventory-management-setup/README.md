# Inventory Management

Deploy an inventory management system where a tracker monitors warehouse stock levels and shipments, a forecaster analyzes sales trends to predict stock needs, and an alerter triggers reorder notifications when stock hits thresholds. The three agents form a closed loop that keeps inventory optimized and prevents stockouts with minimal human intervention.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### tracker (Stock Tracker)
Monitors warehouse stock levels, tracks incoming and outgoing shipments, and updates quantities in real time. Packages current stock snapshots with movement history.

**Skills:** pilot-metrics, pilot-stream-data, pilot-audit-log

### forecaster (Demand Forecaster)
Analyzes sales trends, seasonal patterns, and lead times to predict stock needs. Produces reorder forecasts with recommended quantities and urgency scores.

**Skills:** pilot-dataset, pilot-task-router, pilot-cron

### alerter (Reorder Alerter)
Triggers reorder notifications when stock hits thresholds, sends purchase order requests to suppliers, and notifies procurement teams via Slack.

**Skills:** pilot-alert, pilot-webhook-bridge, pilot-slack-bridge

## Data Flow

```
tracker    --> forecaster : Stock snapshots with quantities and movement history (port 1002)
forecaster --> alerter    : Reorder forecasts with quantities and urgency scores (port 1002)
alerter    --> external   : Purchase order requests to suppliers (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (stock tracker)
clawhub install pilot-metrics pilot-stream-data pilot-audit-log
pilotctl set-hostname <your-prefix>-tracker

# On server 2 (demand forecaster)
clawhub install pilot-dataset pilot-task-router pilot-cron
pilotctl set-hostname <your-prefix>-forecaster

# On server 3 (reorder alerter)
clawhub install pilot-alert pilot-webhook-bridge pilot-slack-bridge
pilotctl set-hostname <your-prefix>-alerter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# tracker <-> forecaster
# On tracker:
pilotctl handshake <your-prefix>-forecaster "setup: inventory-management"
# On forecaster:
pilotctl handshake <your-prefix>-tracker "setup: inventory-management"

# forecaster <-> alerter
# On forecaster:
pilotctl handshake <your-prefix>-alerter "setup: inventory-management"
# On alerter:
pilotctl handshake <your-prefix>-forecaster "setup: inventory-management"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-forecaster -- subscribe to stock snapshots:
pilotctl subscribe <your-prefix>-tracker stock-snapshot

# On <your-prefix>-alerter -- subscribe to reorder forecasts:
pilotctl subscribe <your-prefix>-forecaster reorder-forecast

# On <your-prefix>-tracker -- publish a stock snapshot:
pilotctl publish <your-prefix>-forecaster stock-snapshot '{"warehouse":"us-east-1","sku":"WIDGET-A100","quantity_on_hand":142,"quantity_reserved":38,"incoming_shipments":2,"daily_velocity":12,"last_updated":"2026-04-10T14:30:00Z"}'

# On <your-prefix>-forecaster -- publish a reorder forecast to the alerter:
pilotctl publish <your-prefix>-alerter reorder-forecast '{"sku":"WIDGET-A100","current_stock":142,"predicted_demand_30d":360,"reorder_quantity":500,"urgency":"high","lead_time_days":14,"stockout_risk":"2026-04-22"}'

# The alerter sends a purchase order to the supplier:
pilotctl publish <your-prefix>-alerter purchase-order '{"channel":"#procurement","text":"Reorder triggered: WIDGET-A100 x500 units","supplier":"Acme Supply Co","po_number":"PO-2026-0847","url":"https://erp.acme.com/po/2026-0847"}'
```
