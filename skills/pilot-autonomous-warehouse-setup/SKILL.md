---
name: pilot-autonomous-warehouse-setup
description: >
  Deploy an autonomous warehouse orchestration system with 4 agents.

  Use this skill when:
  1. User wants to set up warehouse automation with robot fleet coordination
  2. User is configuring agents for inventory tracking, pick optimization, or dock scheduling
  3. User asks about warehouse robotics, order fulfillment pipelines, or logistics orchestration

  Do NOT use this skill when:
  - User wants a single task queue (use pilot-task-router instead)
  - User only needs metrics collection (use pilot-metrics instead)
  - User wants basic load balancing without warehouse context (use pilot-load-balancer instead)
tags:
  - pilot-protocol
  - setup
  - warehouse
  - logistics
  - robotics
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

# Autonomous Warehouse Setup

Deploy 4 agents: fleet-controller, inventory-brain, pick-optimizer, and dock-manager.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| fleet-controller | `<prefix>-fleet-controller` | pilot-task-router, pilot-load-balancer, pilot-cron | Manages robot fleet, assigns tasks, optimizes routes |
| inventory-brain | `<prefix>-inventory-brain` | pilot-dataset, pilot-metrics, pilot-consensus | Tracks bin locations, triggers replenishment |
| pick-optimizer | `<prefix>-pick-optimizer` | pilot-task-parallel, pilot-event-filter, pilot-escrow | Batches orders into optimal pick waves |
| dock-manager | `<prefix>-dock-manager` | pilot-webhook-bridge, pilot-receipt, pilot-audit-log | Coordinates inbound/outbound shipments |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For fleet-controller:
clawhub install pilot-task-router pilot-load-balancer pilot-cron
# For inventory-brain:
clawhub install pilot-dataset pilot-metrics pilot-consensus
# For pick-optimizer:
clawhub install pilot-task-parallel pilot-event-filter pilot-escrow
# For dock-manager:
clawhub install pilot-webhook-bridge pilot-receipt pilot-audit-log
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/autonomous-warehouse.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

## Manifest Templates Per Role

### fleet-controller
```json
{
  "setup": "autonomous-warehouse", "role": "fleet-controller", "role_name": "Robot Fleet Controller",
  "hostname": "<prefix>-fleet-controller",
  "skills": {
    "pilot-task-router": "Assign pick tasks to available robots.",
    "pilot-load-balancer": "Distribute workload across robot fleet.",
    "pilot-cron": "Schedule charging cycles and maintenance windows."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-inventory-brain", "port": 1002, "topic": "robot-status", "description": "Robot status and completed task reports" },
    { "direction": "receive", "peer": "<prefix>-pick-optimizer", "port": 1002, "topic": "pick-assignment", "description": "Pick wave assignments for dispatch" }
  ],
  "handshakes_needed": ["<prefix>-inventory-brain", "<prefix>-pick-optimizer"]
}
```

### inventory-brain
```json
{
  "setup": "autonomous-warehouse", "role": "inventory-brain", "role_name": "Inventory Brain",
  "hostname": "<prefix>-inventory-brain",
  "skills": {
    "pilot-dataset": "Maintain real-time bin locations and SKU counts.",
    "pilot-metrics": "Track stock levels, pick rates, and replenishment velocity.",
    "pilot-consensus": "Reconcile inventory counts across zone scanners."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-fleet-controller", "port": 1002, "topic": "robot-status", "description": "Robot status updates" },
    { "direction": "send", "peer": "<prefix>-pick-optimizer", "port": 1002, "topic": "pick-request", "description": "Pick requests with bin locations" },
    { "direction": "receive", "peer": "<prefix>-dock-manager", "port": 1002, "topic": "inbound-shipment", "description": "Inbound shipment data" }
  ],
  "handshakes_needed": ["<prefix>-fleet-controller", "<prefix>-pick-optimizer", "<prefix>-dock-manager"]
}
```

### pick-optimizer
```json
{
  "setup": "autonomous-warehouse", "role": "pick-optimizer", "role_name": "Pick Optimizer",
  "hostname": "<prefix>-pick-optimizer",
  "skills": {
    "pilot-task-parallel": "Batch orders into parallel pick waves.",
    "pilot-event-filter": "Prioritize same-day and rush orders.",
    "pilot-escrow": "Hold payment escrow until order fulfillment confirmed."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-inventory-brain", "port": 1002, "topic": "pick-request", "description": "Pick requests from inventory" },
    { "direction": "send", "peer": "<prefix>-fleet-controller", "port": 1002, "topic": "pick-assignment", "description": "Optimized pick assignments" },
    { "direction": "send", "peer": "<prefix>-dock-manager", "port": 1002, "topic": "outbound-ready", "description": "Orders ready for shipping" }
  ],
  "handshakes_needed": ["<prefix>-inventory-brain", "<prefix>-fleet-controller", "<prefix>-dock-manager"]
}
```

### dock-manager
```json
{
  "setup": "autonomous-warehouse", "role": "dock-manager", "role_name": "Dock Manager",
  "hostname": "<prefix>-dock-manager",
  "skills": {
    "pilot-webhook-bridge": "Notify carriers of shipment readiness.",
    "pilot-receipt": "Generate receiving and shipping receipts.",
    "pilot-audit-log": "Log all dock door assignments and truck movements."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-inventory-brain", "port": 1002, "topic": "inbound-shipment", "description": "Inbound shipment receiving data" },
    { "direction": "receive", "peer": "<prefix>-pick-optimizer", "port": 1002, "topic": "outbound-ready", "description": "Orders ready for outbound" }
  ],
  "handshakes_needed": ["<prefix>-inventory-brain", "<prefix>-pick-optimizer"]
}
```

## Data Flows

- `fleet-controller -> inventory-brain` : robot status and completed task reports (port 1002)
- `inventory-brain -> pick-optimizer` : pick requests with bin locations (port 1002)
- `pick-optimizer -> fleet-controller` : optimized pick assignments (port 1002)
- `dock-manager -> inventory-brain` : inbound shipment receiving data (port 1002)
- `pick-optimizer -> dock-manager` : orders ready for outbound shipping (port 1002)

## Workflow Example

```bash
# On fleet-controller -- report robot status:
pilotctl --json publish <prefix>-inventory-brain robot-status '{"robot_id":"AMR-07","zone":"A3","battery":72,"status":"idle"}'
# On inventory-brain -- send pick request:
pilotctl --json publish <prefix>-pick-optimizer pick-request '{"order_id":"ORD-88412","items":[{"sku":"WH-4410","bin":"A3-07-02","qty":2}]}'
# On pick-optimizer -- assign to fleet:
pilotctl --json publish <prefix>-fleet-controller pick-assignment '{"wave_id":"WAVE-334","robot_id":"AMR-07","stops":["A3-07-02","A3-00-PACK"]}'
# On dock-manager -- notify inbound:
pilotctl --json publish <prefix>-inventory-brain inbound-shipment '{"shipment_id":"SHP-10042","dock_door":3,"pallets":12}'
# On pick-optimizer -- outbound ready:
pilotctl --json publish <prefix>-dock-manager outbound-ready '{"wave_id":"WAVE-334","orders":["ORD-88412"]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
