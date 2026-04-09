# Smart Home Coordinator Setup

A decentralized smart home system where sensors, a central brain, device actuators, and a dashboard collaborate to maintain comfort and efficiency. The brain resolves conflicts between goals (comfort vs. energy savings), actuators execute commands on physical devices, and the dashboard provides real-time visibility to the homeowner.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### sensor-hub (Sensor Hub)
Collects readings from temperature, humidity, light, motion, and energy sensors across the home. Normalizes data into a unified format and publishes periodic snapshots to the brain.

**Skills:** pilot-stream-data, pilot-cron, pilot-metrics

### brain (Home Brain)
Central coordinator that receives sensor data, applies user preferences, resolves conflicts between device goals (comfort vs. energy savings), and issues commands to the actuator. Maintains current home state for the dashboard.

**Skills:** pilot-event-filter, pilot-task-router, pilot-consensus

### actuator (Device Actuator)
Executes commands on smart devices -- HVAC, lighting, locks, shutters. Reports confirmation or failure back to the brain so it can retry or alert the homeowner.

**Skills:** pilot-task-router, pilot-receipt, pilot-audit-log

### dashboard (Home Dashboard)
Displays real-time home status, energy usage trends, and room-by-room breakdowns. Sends daily summaries to the homeowner via Slack or email.

**Skills:** pilot-metrics, pilot-webhook-bridge, pilot-slack-bridge

## Data Flow

```
sensor-hub --> brain     : sensor readings (port 1002)
brain      --> actuator  : device commands (port 1002)
actuator   --> brain     : action confirmations (port 1002)
brain      --> dashboard : home state updates (port 1002)
dashboard  --> external  : daily summary via Slack/email (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `myhome`).

### 1. Install skills on each server

```bash
# On server 1 (sensor hub)
clawhub install pilot-stream-data pilot-cron pilot-metrics
pilotctl set-hostname <your-prefix>-sensor-hub

# On server 2 (home brain)
clawhub install pilot-event-filter pilot-task-router pilot-consensus
pilotctl set-hostname <your-prefix>-brain

# On server 3 (device actuator)
clawhub install pilot-task-router pilot-receipt pilot-audit-log
pilotctl set-hostname <your-prefix>-actuator

# On server 4 (home dashboard)
clawhub install pilot-metrics pilot-webhook-bridge pilot-slack-bridge
pilotctl set-hostname <your-prefix>-dashboard
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# sensor-hub <-> brain (sensor data flow)
# On sensor-hub:
pilotctl handshake <your-prefix>-brain "setup: smart-home-coordinator"
# On brain:
pilotctl handshake <your-prefix>-sensor-hub "setup: smart-home-coordinator"

# brain <-> actuator (device commands and confirmations)
# On brain:
pilotctl handshake <your-prefix>-actuator "setup: smart-home-coordinator"
# On actuator:
pilotctl handshake <your-prefix>-brain "setup: smart-home-coordinator"

# brain <-> dashboard (home state updates)
# On brain:
pilotctl handshake <your-prefix>-dashboard "setup: smart-home-coordinator"
# On dashboard:
pilotctl handshake <your-prefix>-brain "setup: smart-home-coordinator"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-sensor-hub -- publish sensor readings:
pilotctl publish <your-prefix>-brain sensor-reading '{"room":"living-room","temperature_c":23.4,"humidity_pct":45,"light_lux":320,"motion":false,"energy_w":1250,"timestamp":"2026-04-09T14:30:00Z"}'

# On <your-prefix>-brain -- publish a device command:
pilotctl publish <your-prefix>-actuator device-command '{"device":"hvac-main","action":"set_temperature","params":{"target_c":22,"mode":"cool"},"reason":"temperature above comfort threshold","priority":"normal"}'

# On <your-prefix>-actuator -- publish action confirmation:
pilotctl publish <your-prefix>-brain action-confirm '{"device":"hvac-main","action":"set_temperature","status":"success","current_target_c":22,"response_time_ms":340}'

# On <your-prefix>-brain -- publish home state to dashboard:
pilotctl publish <your-prefix>-dashboard home-state '{"rooms":{"living-room":{"temp_c":23.4,"target_c":22,"hvac":"cooling"},"bedroom":{"temp_c":21.0,"target_c":21,"hvac":"idle"}},"total_energy_w":1250,"mode":"comfort"}'

# On <your-prefix>-dashboard -- subscribe to home state:
pilotctl subscribe home-state
```
