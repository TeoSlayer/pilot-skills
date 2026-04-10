# Autonomous Warehouse

An autonomous warehouse orchestration system that coordinates robot fleets, tracks inventory in real time, optimizes pick waves for order fulfillment, and manages dock scheduling for inbound and outbound shipments. The fleet controller dispatches robots, the inventory brain maintains bin-level location data, the pick optimizer batches orders into efficient waves, and the dock manager coordinates truck arrivals and departures.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### fleet-controller (Robot Fleet Controller)
Manages warehouse robot fleet -- assigns pick tasks, optimizes routes between aisles, handles charging schedules, and monitors robot health. Tracks robot positions and battery levels in real time.

**Skills:** pilot-task-router, pilot-load-balancer, pilot-cron

### inventory-brain (Inventory Brain)
Maintains real-time bin locations for every SKU, triggers replenishment when stock drops below thresholds, and optimizes slotting to minimize pick travel distance. Tracks inventory counts across all zones.

**Skills:** pilot-dataset, pilot-metrics, pilot-consensus

### pick-optimizer (Pick Optimizer)
Batches incoming orders into optimal pick waves that minimize robot travel distance, handles priority and same-day orders, and balances workload across available robots. Coordinates payment escrow for fulfilled orders.

**Skills:** pilot-task-parallel, pilot-event-filter, pilot-escrow

### dock-manager (Dock Manager)
Coordinates inbound receiving and outbound shipping -- assigns dock doors, schedules truck arrival windows, triggers putaway tasks for inbound goods, and notifies carriers when shipments are staged.

**Skills:** pilot-webhook-bridge, pilot-receipt, pilot-audit-log

## Data Flow

```
fleet-controller --> inventory-brain  : Robot status and completed task reports (port 1002)
inventory-brain  --> pick-optimizer   : Pick requests with bin locations (port 1002)
pick-optimizer   --> fleet-controller : Pick assignments for robot dispatch (port 1002)
dock-manager     --> inventory-brain  : Inbound shipment receiving data (port 1002)
pick-optimizer   --> dock-manager     : Outbound orders ready for shipping (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On fleet controller node
clawhub install pilot-task-router pilot-load-balancer pilot-cron
pilotctl set-hostname <your-prefix>-fleet-controller

# On inventory brain node
clawhub install pilot-dataset pilot-metrics pilot-consensus
pilotctl set-hostname <your-prefix>-inventory-brain

# On pick optimizer node
clawhub install pilot-task-parallel pilot-event-filter pilot-escrow
pilotctl set-hostname <your-prefix>-pick-optimizer

# On dock manager node
clawhub install pilot-webhook-bridge pilot-receipt pilot-audit-log
pilotctl set-hostname <your-prefix>-dock-manager
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# fleet-controller <-> inventory-brain (robot status)
# On fleet-controller:
pilotctl handshake <your-prefix>-inventory-brain "setup: autonomous-warehouse"
# On inventory-brain:
pilotctl handshake <your-prefix>-fleet-controller "setup: autonomous-warehouse"

# inventory-brain <-> pick-optimizer (pick requests)
# On inventory-brain:
pilotctl handshake <your-prefix>-pick-optimizer "setup: autonomous-warehouse"
# On pick-optimizer:
pilotctl handshake <your-prefix>-inventory-brain "setup: autonomous-warehouse"

# pick-optimizer <-> fleet-controller (pick assignments)
# On pick-optimizer:
pilotctl handshake <your-prefix>-fleet-controller "setup: autonomous-warehouse"
# On fleet-controller:
pilotctl handshake <your-prefix>-pick-optimizer "setup: autonomous-warehouse"

# dock-manager <-> inventory-brain (inbound shipments)
# On dock-manager:
pilotctl handshake <your-prefix>-inventory-brain "setup: autonomous-warehouse"
# On inventory-brain:
pilotctl handshake <your-prefix>-dock-manager "setup: autonomous-warehouse"

# pick-optimizer <-> dock-manager (outbound ready)
# On pick-optimizer:
pilotctl handshake <your-prefix>-dock-manager "setup: autonomous-warehouse"
# On dock-manager:
pilotctl handshake <your-prefix>-pick-optimizer "setup: autonomous-warehouse"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-fleet-controller -- report robot status to inventory brain:
pilotctl publish <your-prefix>-inventory-brain robot-status '{"robot_id":"AMR-07","zone":"A3","battery":72,"status":"idle","last_task":"PICK-2291","completed_at":"2026-04-10T14:22:00Z"}'

# On <your-prefix>-inventory-brain -- send pick request to optimizer:
pilotctl publish <your-prefix>-pick-optimizer pick-request '{"order_id":"ORD-88412","items":[{"sku":"WH-4410","bin":"A3-07-02","qty":2},{"sku":"WH-1198","bin":"A3-12-01","qty":1}],"priority":"standard"}'

# On <your-prefix>-pick-optimizer -- assign pick wave to fleet:
pilotctl publish <your-prefix>-fleet-controller pick-assignment '{"wave_id":"WAVE-334","robot_id":"AMR-07","stops":["A3-07-02","A3-12-01","A3-00-PACK"],"estimated_time_sec":145}'

# On <your-prefix>-dock-manager -- notify inventory of inbound shipment:
pilotctl publish <your-prefix>-inventory-brain inbound-shipment '{"shipment_id":"SHP-10042","dock_door":3,"carrier":"FastFreight","pallets":12,"expected_skus":["WH-4410","WH-5521","WH-3390"]}'

# On <your-prefix>-pick-optimizer -- notify dock that outbound is ready:
pilotctl publish <your-prefix>-dock-manager outbound-ready '{"wave_id":"WAVE-334","orders":["ORD-88412","ORD-88415"],"packed_at":"2026-04-10T14:35:00Z","dock_door_requested":5}'
```
