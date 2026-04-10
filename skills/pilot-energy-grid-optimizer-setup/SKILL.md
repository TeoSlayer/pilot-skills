---
name: pilot-energy-grid-optimizer-setup
description: >
  Deploy an energy grid optimization system with 4 agents.

  Use this skill when:
  1. User wants to set up coordinated energy monitoring, forecasting, optimization, and device control agents
  2. User is configuring a smart grid, microgrid, or distributed energy resource management workflow
  3. User asks about demand forecasting, battery scheduling, or load balancing across energy sources

  Do NOT use this skill when:
  - User wants a single sensor data stream (use pilot-stream-data instead)
  - User wants to send a one-off device command (use pilot-webhook-bridge instead)
  - User only needs scheduled metrics collection (use pilot-cron instead)
tags:
  - pilot-protocol
  - setup
  - energy
  - smart-grid
  - iot
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

# Energy Grid Optimizer Setup

Deploy 4 agents: sensor-mesh, forecaster, optimizer, and controller.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| sensor-mesh | `<prefix>-sensor-mesh` | pilot-stream-data, pilot-metrics, pilot-gossip | Aggregates real-time grid sensor readings |
| forecaster | `<prefix>-forecaster` | pilot-dataset, pilot-task-router, pilot-cron | Predicts energy demand from weather and history |
| optimizer | `<prefix>-optimizer` | pilot-consensus, pilot-event-filter, pilot-audit-log | Balances load, schedules battery cycles |
| controller | `<prefix>-controller` | pilot-webhook-bridge, pilot-receipt, pilot-alert | Sends device commands, confirms execution |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For sensor-mesh:
clawhub install pilot-stream-data pilot-metrics pilot-gossip
# For forecaster:
clawhub install pilot-dataset pilot-task-router pilot-cron
# For optimizer:
clawhub install pilot-consensus pilot-event-filter pilot-audit-log
# For controller:
clawhub install pilot-webhook-bridge pilot-receipt pilot-alert
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/energy-grid-optimizer.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

**Step 5:** Verify connectivity with `pilotctl --json trust`.

## Manifest Templates Per Role

### sensor-mesh
```json
{"setup":"energy-grid-optimizer","role":"sensor-mesh","role_name":"Sensor Mesh","hostname":"<prefix>-sensor-mesh","skills":{"pilot-stream-data":"Ingest real-time readings from smart meters, solar panels, and batteries.","pilot-metrics":"Track grid voltage, frequency, and power quality metrics.","pilot-gossip":"Share sensor health status across mesh nodes."},"data_flows":[{"direction":"send","peer":"<prefix>-forecaster","port":1002,"topic":"grid-reading","description":"Timestamped grid readings"},{"direction":"receive","peer":"<prefix>-controller","port":1002,"topic":"device-ack","description":"Device execution confirmations"}],"handshakes_needed":["<prefix>-forecaster","<prefix>-controller"]}
```

### forecaster
```json
{"setup":"energy-grid-optimizer","role":"forecaster","role_name":"Load Forecaster","hostname":"<prefix>-forecaster","skills":{"pilot-dataset":"Store historical demand and weather data for model training.","pilot-task-router":"Route forecast jobs across time horizons.","pilot-cron":"Run scheduled forecast updates every 15 minutes."},"data_flows":[{"direction":"receive","peer":"<prefix>-sensor-mesh","port":1002,"topic":"grid-reading","description":"Real-time grid readings"},{"direction":"send","peer":"<prefix>-optimizer","port":1002,"topic":"demand-forecast","description":"Demand forecasts with confidence intervals"}],"handshakes_needed":["<prefix>-sensor-mesh","<prefix>-optimizer"]}
```

### optimizer
```json
{"setup":"energy-grid-optimizer","role":"optimizer","role_name":"Grid Optimizer","hostname":"<prefix>-optimizer","skills":{"pilot-consensus":"Coordinate optimization decisions across distributed sources.","pilot-event-filter":"Filter forecasts by confidence threshold before acting.","pilot-audit-log":"Log all dispatch decisions with cost and reasoning."},"data_flows":[{"direction":"receive","peer":"<prefix>-forecaster","port":1002,"topic":"demand-forecast","description":"Demand forecasts from forecaster"},{"direction":"send","peer":"<prefix>-controller","port":1002,"topic":"dispatch-command","description":"Device setpoint commands"}],"handshakes_needed":["<prefix>-forecaster","<prefix>-controller"]}
```

### controller
```json
{"setup":"energy-grid-optimizer","role":"controller","role_name":"Device Controller","hostname":"<prefix>-controller","skills":{"pilot-webhook-bridge":"Interface with inverter and battery management APIs.","pilot-receipt":"Generate execution confirmations for each command.","pilot-alert":"Emit alerts on device failures or safety threshold breaches."},"data_flows":[{"direction":"receive","peer":"<prefix>-optimizer","port":1002,"topic":"dispatch-command","description":"Dispatch commands to execute"},{"direction":"send","peer":"<prefix>-sensor-mesh","port":1002,"topic":"device-ack","description":"Execution status confirmations"}],"handshakes_needed":["<prefix>-optimizer","<prefix>-sensor-mesh"]}
```

## Data Flows

- `sensor-mesh -> forecaster` : grid readings with voltage, current, and power metrics (port 1002)
- `forecaster -> optimizer` : demand forecasts with confidence intervals (port 1002)
- `optimizer -> controller` : dispatch commands for device setpoints (port 1002)
- `controller -> sensor-mesh` : device acknowledgments with execution status (port 1002)

## Handshakes

```bash
pilotctl --json handshake <prefix>-forecaster "setup: energy-grid-optimizer"
pilotctl --json handshake <prefix>-sensor-mesh "setup: energy-grid-optimizer"
pilotctl --json handshake <prefix>-optimizer "setup: energy-grid-optimizer"
pilotctl --json handshake <prefix>-controller "setup: energy-grid-optimizer"
```

## Workflow Example

```bash
# On sensor-mesh -- publish grid reading:
pilotctl --json publish <prefix>-forecaster grid-reading '{"source":"solar-array-1","power_kw":5.1,"battery_soc":0.73}'
# On forecaster -- publish demand forecast:
pilotctl --json publish <prefix>-optimizer demand-forecast '{"horizon":"1h","predicted_kw":42.8,"confidence":0.91}'
# On optimizer -- publish dispatch command:
pilotctl --json publish <prefix>-controller dispatch-command '{"device":"battery-bank-1","action":"discharge","setpoint_kw":10.0}'
# On controller -- publish device ack:
pilotctl --json publish <prefix>-sensor-mesh device-ack '{"device":"battery-bank-1","status":"executing","actual_kw":9.8}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
