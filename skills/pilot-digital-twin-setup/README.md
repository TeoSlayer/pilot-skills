# Digital Twin

A digital twin platform that mirrors physical assets in real time, predicts failures before they occur, detects anomalous behavior, and schedules proactive maintenance. The sensor bridge ingests live telemetry, the model engine maintains a physics-based simulation, the anomaly detector compares real versus predicted behavior, and the action planner recommends and schedules interventions.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### sensor-bridge (Sensor Bridge)
Ingests real-time telemetry from physical assets -- temperature, vibration, pressure, and flow rates. Normalizes sensor data across protocols, handles sampling rate mismatches, and forwards unified telemetry streams to the model engine.

**Skills:** pilot-stream-data, pilot-metrics, pilot-gossip

### model-engine (Model Engine)
Maintains a physics-based digital twin model of each monitored asset, runs simulations against incoming telemetry, predicts component degradation curves, and generates expected behavior baselines for anomaly comparison.

**Skills:** pilot-dataset, pilot-task-router, pilot-consensus

### anomaly-detector (Anomaly Detector)
Compares real-time sensor readings against model predictions, detects statistical drift and degradation patterns, classifies anomalies by severity and root cause, and triggers alerts when thresholds are exceeded.

**Skills:** pilot-event-filter, pilot-alert, pilot-audit-log

### action-planner (Action Planner)
Recommends maintenance actions based on anomaly severity and degradation forecasts, schedules maintenance windows to minimize downtime, notifies field teams via webhooks and messaging integrations, and tracks intervention outcomes.

**Skills:** pilot-webhook-bridge, pilot-cron, pilot-slack-bridge

## Data Flow

```
sensor-bridge    --> model-engine     : Real-time telemetry from physical assets (port 1002)
model-engine     --> anomaly-detector : Predictions and expected behavior baselines (port 1002)
anomaly-detector --> action-planner   : Anomaly alerts with severity and root cause (port 1002)
action-planner   --> external         : Maintenance orders to field team systems (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On sensor bridge node
clawhub install pilot-stream-data pilot-metrics pilot-gossip
pilotctl set-hostname <your-prefix>-sensor-bridge

# On model engine node
clawhub install pilot-dataset pilot-task-router pilot-consensus
pilotctl set-hostname <your-prefix>-model-engine

# On anomaly detector node
clawhub install pilot-event-filter pilot-alert pilot-audit-log
pilotctl set-hostname <your-prefix>-anomaly-detector

# On action planner node
clawhub install pilot-webhook-bridge pilot-cron pilot-slack-bridge
pilotctl set-hostname <your-prefix>-action-planner
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# sensor-bridge <-> model-engine (telemetry)
# On sensor-bridge:
pilotctl handshake <your-prefix>-model-engine "setup: digital-twin"
# On model-engine:
pilotctl handshake <your-prefix>-sensor-bridge "setup: digital-twin"

# model-engine <-> anomaly-detector (predictions)
# On model-engine:
pilotctl handshake <your-prefix>-anomaly-detector "setup: digital-twin"
# On anomaly-detector:
pilotctl handshake <your-prefix>-model-engine "setup: digital-twin"

# anomaly-detector <-> action-planner (anomaly alerts)
# On anomaly-detector:
pilotctl handshake <your-prefix>-action-planner "setup: digital-twin"
# On action-planner:
pilotctl handshake <your-prefix>-anomaly-detector "setup: digital-twin"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-sensor-bridge -- stream telemetry to model engine:
pilotctl publish <your-prefix>-model-engine telemetry '{"asset_id":"PUMP-A7","timestamp":"2026-04-10T14:30:00Z","sensors":{"temperature_c":87.3,"vibration_mm_s":4.2,"pressure_bar":6.8,"flow_rate_lpm":142.5},"sampling_hz":10}'

# On <your-prefix>-model-engine -- send prediction to anomaly detector:
pilotctl publish <your-prefix>-anomaly-detector prediction '{"asset_id":"PUMP-A7","timestamp":"2026-04-10T14:30:00Z","expected":{"temperature_c":82.1,"vibration_mm_s":2.8,"pressure_bar":7.0,"flow_rate_lpm":150.0},"actual":{"temperature_c":87.3,"vibration_mm_s":4.2,"pressure_bar":6.8,"flow_rate_lpm":142.5},"drift_pct":{"temperature":6.3,"vibration":50.0,"pressure":2.9,"flow_rate":5.0}}'

# On <your-prefix>-anomaly-detector -- alert action planner:
pilotctl publish <your-prefix>-action-planner anomaly-alert '{"asset_id":"PUMP-A7","severity":"warning","anomaly_type":"bearing_degradation","confidence":0.89,"indicators":["vibration_50pct_above_baseline","temperature_rising_trend"],"estimated_failure_days":14}'

# On <your-prefix>-action-planner -- subscribe to anomaly alerts:
pilotctl subscribe <your-prefix>-anomaly-detector anomaly-alert
```
