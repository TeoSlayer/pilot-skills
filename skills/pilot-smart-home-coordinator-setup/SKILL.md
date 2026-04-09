---
name: pilot-smart-home-coordinator-setup
description: >
  Deploy a smart home coordinator with 4 agents.

  Use this skill when:
  1. User wants to set up a smart home automation or IoT coordination system
  2. User is configuring a sensor hub, home brain, actuator, or dashboard agent
  3. User asks about home automation, device control, or sensor data workflows

  Do NOT use this skill when:
  - User wants to stream generic data (use pilot-stream-data instead)
  - User wants to set up a single cron job (use pilot-cron instead)
tags:
  - pilot-protocol
  - setup
  - iot
  - smart-home
  - automation
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

# Smart Home Coordinator Setup

Deploy 4 agents that sense, decide, act, and display in a decentralized smart home system.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| sensor-hub | `<prefix>-sensor-hub` | pilot-stream-data, pilot-cron, pilot-metrics | Collects and normalizes sensor readings |
| brain | `<prefix>-brain` | pilot-event-filter, pilot-task-router, pilot-consensus | Resolves goals, issues device commands |
| actuator | `<prefix>-actuator` | pilot-task-router, pilot-receipt, pilot-audit-log | Executes commands on devices, reports results |
| dashboard | `<prefix>-dashboard` | pilot-metrics, pilot-webhook-bridge, pilot-slack-bridge | Displays home status, sends daily summaries |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For sensor-hub:
clawhub install pilot-stream-data pilot-cron pilot-metrics
# For brain:
clawhub install pilot-event-filter pilot-task-router pilot-consensus
# For actuator:
clawhub install pilot-task-router pilot-receipt pilot-audit-log
# For dashboard:
clawhub install pilot-metrics pilot-webhook-bridge pilot-slack-bridge
```

**Step 3:** Set the hostname and write the manifest:
```bash
pilotctl --json set-hostname <prefix>-<role>
mkdir -p ~/.pilot/setups
```
Then write the role-specific JSON manifest to `~/.pilot/setups/smart-home-coordinator.json`.

**Step 4:** Tell the user to initiate handshakes with adjacent agents.

## Manifest Templates Per Role

### sensor-hub
```json
{
  "setup": "smart-home-coordinator", "role": "sensor-hub", "role_name": "Sensor Hub",
  "hostname": "<prefix>-sensor-hub",
  "skills": { "pilot-stream-data": "Stream sensor snapshots to brain.", "pilot-cron": "Schedule polling intervals.", "pilot-metrics": "Normalize raw sensor values." },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-brain", "port": 1002, "topic": "sensor-reading" }],
  "handshakes_needed": ["<prefix>-brain"]
}
```

### brain
```json
{
  "setup": "smart-home-coordinator", "role": "brain", "role_name": "Home Brain",
  "hostname": "<prefix>-brain",
  "skills": { "pilot-event-filter": "Filter by threshold and room.", "pilot-task-router": "Route commands to actuator.", "pilot-consensus": "Resolve comfort vs energy goals." },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-sensor-hub", "port": 1002, "topic": "sensor-reading" },
    { "direction": "send", "peer": "<prefix>-actuator", "port": 1002, "topic": "device-command" },
    { "direction": "receive", "peer": "<prefix>-actuator", "port": 1002, "topic": "action-confirm" },
    { "direction": "send", "peer": "<prefix>-dashboard", "port": 1002, "topic": "home-state" }
  ],
  "handshakes_needed": ["<prefix>-sensor-hub", "<prefix>-actuator", "<prefix>-dashboard"]
}
```

### actuator
```json
{
  "setup": "smart-home-coordinator", "role": "actuator", "role_name": "Device Actuator",
  "hostname": "<prefix>-actuator",
  "skills": { "pilot-task-router": "Dispatch device commands.", "pilot-receipt": "Confirm actions to brain.", "pilot-audit-log": "Log device actions for safety." },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-brain", "port": 1002, "topic": "device-command" },
    { "direction": "send", "peer": "<prefix>-brain", "port": 1002, "topic": "action-confirm" }
  ],
  "handshakes_needed": ["<prefix>-brain"]
}
```

### dashboard
```json
{
  "setup": "smart-home-coordinator", "role": "dashboard", "role_name": "Home Dashboard",
  "hostname": "<prefix>-dashboard",
  "skills": { "pilot-metrics": "Track energy and room stats.", "pilot-webhook-bridge": "Send daily reports.", "pilot-slack-bridge": "Post status to Slack." },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-brain", "port": 1002, "topic": "home-state" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "daily-summary" }
  ],
  "handshakes_needed": ["<prefix>-brain"]
}
```

## Data Flows

- `sensor-hub -> brain` : sensor readings (port 1002)
- `brain -> actuator` : device commands (port 1002)
- `actuator -> brain` : action confirmations (port 1002)
- `brain -> dashboard` : home state updates (port 1002)
- `dashboard -> external` : daily summary via Slack/email (port 443)

## Handshakes

```bash
# sensor-hub <-> brain:
pilotctl --json handshake <prefix>-brain "setup: smart-home-coordinator"
pilotctl --json handshake <prefix>-sensor-hub "setup: smart-home-coordinator"
# brain <-> actuator:
pilotctl --json handshake <prefix>-actuator "setup: smart-home-coordinator"
pilotctl --json handshake <prefix>-brain "setup: smart-home-coordinator"
# brain <-> dashboard:
pilotctl --json handshake <prefix>-dashboard "setup: smart-home-coordinator"
pilotctl --json handshake <prefix>-brain "setup: smart-home-coordinator"
```

## Workflow Example

```bash
# On sensor-hub -- publish sensor reading:
pilotctl --json publish <prefix>-brain sensor-reading '{"room":"living-room","temperature_c":23.4,"humidity_pct":45}'

# On brain -- issue device command:
pilotctl --json publish <prefix>-actuator device-command '{"device":"hvac-main","action":"set_temperature","params":{"target_c":22}}'

# On actuator -- confirm action:
pilotctl --json publish <prefix>-brain action-confirm '{"device":"hvac-main","status":"success"}'

# On brain -- update dashboard:
pilotctl --json publish <prefix>-dashboard home-state '{"rooms":{"living-room":{"temp_c":23.4,"hvac":"cooling"}}}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
