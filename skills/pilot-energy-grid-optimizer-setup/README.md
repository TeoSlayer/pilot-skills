# Energy Grid Optimizer

A multi-agent energy management system that coordinates real-time sensor aggregation, demand forecasting, grid optimization, and device control across four specialized agents. The sensor mesh collects readings from smart meters, solar panels, batteries, and grid sensors. The forecaster predicts energy demand using weather, time-of-day, and historical patterns. The optimizer balances load across sources and schedules battery charge/discharge cycles. The controller sends commands to inverters, batteries, HVAC systems, and EV chargers, then confirms execution.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### sensor-mesh (Sensor Mesh)
Aggregates real-time readings from smart meters, solar panels, batteries, and grid sensors. Normalizes heterogeneous data formats into a unified stream of timestamped grid readings for downstream analysis.

**Skills:** pilot-stream-data, pilot-metrics, pilot-gossip

### forecaster (Load Forecaster)
Predicts energy demand using weather, time-of-day, and historical patterns. Produces rolling demand forecasts at 15-minute, 1-hour, and 24-hour horizons to guide optimization decisions.

**Skills:** pilot-dataset, pilot-task-router, pilot-cron

### optimizer (Grid Optimizer)
Balances load across sources, schedules battery charge/discharge, minimizes cost. Evaluates forecasts against current grid state and issues dispatch commands to maximize renewable utilization while maintaining grid stability.

**Skills:** pilot-consensus, pilot-event-filter, pilot-audit-log

### controller (Device Controller)
Sends commands to inverters, batteries, HVAC, and EV chargers. Confirms execution and reports device acknowledgments back to the sensor mesh for closed-loop verification.

**Skills:** pilot-webhook-bridge, pilot-receipt, pilot-alert

## Data Flow

```
sensor-mesh --> forecaster  : Grid readings with voltage, current, and power metrics (port 1002)
forecaster  --> optimizer   : Demand forecasts with confidence intervals (port 1002)
optimizer   --> controller  : Dispatch commands for device setpoints (port 1002)
controller  --> sensor-mesh : Device acknowledgments with execution status (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On sensor aggregation server
clawhub install pilot-stream-data pilot-metrics pilot-gossip
pilotctl set-hostname <your-prefix>-sensor-mesh

# On forecasting server
clawhub install pilot-dataset pilot-task-router pilot-cron
pilotctl set-hostname <your-prefix>-forecaster

# On optimization server
clawhub install pilot-consensus pilot-event-filter pilot-audit-log
pilotctl set-hostname <your-prefix>-optimizer

# On device control server
clawhub install pilot-webhook-bridge pilot-receipt pilot-alert
pilotctl set-hostname <your-prefix>-controller
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# sensor-mesh <-> forecaster (grid readings)
# On sensor-mesh:
pilotctl handshake <your-prefix>-forecaster "setup: energy-grid-optimizer"
# On forecaster:
pilotctl handshake <your-prefix>-sensor-mesh "setup: energy-grid-optimizer"

# forecaster <-> optimizer (demand forecasts)
# On forecaster:
pilotctl handshake <your-prefix>-optimizer "setup: energy-grid-optimizer"
# On optimizer:
pilotctl handshake <your-prefix>-forecaster "setup: energy-grid-optimizer"

# optimizer <-> controller (dispatch commands)
# On optimizer:
pilotctl handshake <your-prefix>-controller "setup: energy-grid-optimizer"
# On controller:
pilotctl handshake <your-prefix>-optimizer "setup: energy-grid-optimizer"

# controller <-> sensor-mesh (device acknowledgments)
# On controller:
pilotctl handshake <your-prefix>-sensor-mesh "setup: energy-grid-optimizer"
# On sensor-mesh:
pilotctl handshake <your-prefix>-controller "setup: energy-grid-optimizer"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-sensor-mesh -- publish a grid reading:
pilotctl publish <your-prefix>-forecaster grid-reading '{"source":"solar-array-1","voltage_v":408.2,"current_a":12.5,"power_kw":5.1,"battery_soc":0.73,"timestamp":"2026-04-10T14:00:00Z"}'

# On <your-prefix>-forecaster -- publish a demand forecast:
pilotctl publish <your-prefix>-optimizer demand-forecast '{"horizon":"1h","predicted_kw":42.8,"confidence":0.91,"weather":"partly_cloudy","peak_expected":"2026-04-10T18:00:00Z"}'

# On <your-prefix>-optimizer -- publish a dispatch command:
pilotctl publish <your-prefix>-controller dispatch-command '{"device":"battery-bank-1","action":"discharge","setpoint_kw":10.0,"duration_min":60,"priority":"high","reason":"peak_shaving"}'

# On <your-prefix>-controller -- publish a device acknowledgment:
pilotctl publish <your-prefix>-sensor-mesh device-ack '{"device":"battery-bank-1","action":"discharge","status":"executing","actual_kw":9.8,"timestamp":"2026-04-10T17:01:03Z"}'
```
