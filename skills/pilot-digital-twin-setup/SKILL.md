---
name: pilot-digital-twin-setup
description: >
  Deploy a digital twin platform with 4 agents.

  Use this skill when:
  1. User wants to set up a digital twin for physical asset monitoring and predictive maintenance
  2. User is configuring agents for sensor ingestion, physics simulation, or anomaly detection
  3. User asks about predictive maintenance, asset health monitoring, or real-vs-predicted comparison

  Do NOT use this skill when:
  - User wants basic metrics collection (use pilot-metrics instead)
  - User only needs event filtering without a twin model (use pilot-event-filter instead)
  - User wants a single alert notification (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - digital-twin
  - iot
  - predictive-maintenance
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

# Digital Twin Setup

Deploy 4 agents: sensor-bridge, model-engine, anomaly-detector, and action-planner.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| sensor-bridge | `<prefix>-sensor-bridge` | pilot-stream-data, pilot-metrics, pilot-gossip | Ingests real-time telemetry from physical assets |
| model-engine | `<prefix>-model-engine` | pilot-dataset, pilot-task-router, pilot-consensus | Maintains physics model, runs simulations |
| anomaly-detector | `<prefix>-anomaly-detector` | pilot-event-filter, pilot-alert, pilot-audit-log | Detects drift between real and predicted behavior |
| action-planner | `<prefix>-action-planner` | pilot-webhook-bridge, pilot-cron, pilot-slack-bridge | Schedules maintenance, notifies field teams |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For sensor-bridge:
clawhub install pilot-stream-data pilot-metrics pilot-gossip
# For model-engine:
clawhub install pilot-dataset pilot-task-router pilot-consensus
# For anomaly-detector:
clawhub install pilot-event-filter pilot-alert pilot-audit-log
# For action-planner:
clawhub install pilot-webhook-bridge pilot-cron pilot-slack-bridge
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/digital-twin.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

## Manifest Templates Per Role

### sensor-bridge
```json
{
  "setup": "digital-twin", "role": "sensor-bridge", "role_name": "Sensor Bridge",
  "hostname": "<prefix>-sensor-bridge",
  "skills": {
    "pilot-stream-data": "Ingest real-time sensor telemetry from physical assets.",
    "pilot-metrics": "Track sensor health, sampling rates, and data quality.",
    "pilot-gossip": "Discover and sync with peer sensor bridges."
  },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-model-engine", "port": 1002, "topic": "telemetry", "description": "Unified telemetry stream from physical assets" }],
  "handshakes_needed": ["<prefix>-model-engine"]
}
```

### model-engine
```json
{
  "setup": "digital-twin", "role": "model-engine", "role_name": "Model Engine",
  "hostname": "<prefix>-model-engine",
  "skills": {
    "pilot-dataset": "Store physics model parameters and simulation state.",
    "pilot-task-router": "Route simulation tasks across asset models.",
    "pilot-consensus": "Reconcile model state across redundant engines."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-sensor-bridge", "port": 1002, "topic": "telemetry", "description": "Real-time sensor data" },
    { "direction": "send", "peer": "<prefix>-anomaly-detector", "port": 1002, "topic": "prediction", "description": "Expected behavior baselines and drift metrics" }
  ],
  "handshakes_needed": ["<prefix>-sensor-bridge", "<prefix>-anomaly-detector"]
}
```

### anomaly-detector
```json
{
  "setup": "digital-twin", "role": "anomaly-detector", "role_name": "Anomaly Detector",
  "hostname": "<prefix>-anomaly-detector",
  "skills": {
    "pilot-event-filter": "Filter predictions by drift threshold and severity.",
    "pilot-alert": "Emit anomaly alerts for critical deviations.",
    "pilot-audit-log": "Log all detected anomalies with evidence snapshots."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-model-engine", "port": 1002, "topic": "prediction", "description": "Model predictions to compare" },
    { "direction": "send", "peer": "<prefix>-action-planner", "port": 1002, "topic": "anomaly-alert", "description": "Anomaly alerts with severity and root cause" }
  ],
  "handshakes_needed": ["<prefix>-model-engine", "<prefix>-action-planner"]
}
```

### action-planner
```json
{
  "setup": "digital-twin", "role": "action-planner", "role_name": "Action Planner",
  "hostname": "<prefix>-action-planner",
  "skills": {
    "pilot-webhook-bridge": "Push maintenance orders to field team systems.",
    "pilot-cron": "Schedule maintenance windows during low-impact periods.",
    "pilot-slack-bridge": "Notify operations teams of recommended interventions."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-anomaly-detector", "port": 1002, "topic": "anomaly-alert", "description": "Anomaly alerts to act on" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "maintenance-order", "description": "Work orders to field management systems" }
  ],
  "handshakes_needed": ["<prefix>-anomaly-detector"]
}
```

## Data Flows

- `sensor-bridge -> model-engine` : real-time telemetry from physical assets (port 1002)
- `model-engine -> anomaly-detector` : predictions and expected behavior baselines (port 1002)
- `anomaly-detector -> action-planner` : anomaly alerts with severity and root cause (port 1002)
- `action-planner -> external` : maintenance orders to field team systems (port 443)

## Workflow Example

```bash
# On sensor-bridge -- stream telemetry:
pilotctl --json publish <prefix>-model-engine telemetry '{"asset_id":"PUMP-A7","sensors":{"temperature_c":87.3,"vibration_mm_s":4.2}}'
# On model-engine -- send prediction:
pilotctl --json publish <prefix>-anomaly-detector prediction '{"asset_id":"PUMP-A7","drift_pct":{"temperature":6.3,"vibration":50.0}}'
# On anomaly-detector -- alert planner:
pilotctl --json publish <prefix>-action-planner anomaly-alert '{"asset_id":"PUMP-A7","severity":"warning","anomaly_type":"bearing_degradation"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
