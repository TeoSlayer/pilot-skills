---
name: pilot-disaster-response-setup
description: >
  Deploy a disaster response coordination system with 4 agents.

  Use this skill when:
  1. User wants to set up coordinated disaster monitoring, response coordination, resource allocation, and communications agents
  2. User is configuring an emergency management, incident response, or public safety workflow
  3. User asks about disaster alert pipelines, resource deployment optimization, or emergency broadcast systems

  Do NOT use this skill when:
  - User wants a single alert notification (use pilot-alert instead)
  - User wants to broadcast a one-off announcement (use pilot-announce instead)
  - User only needs sensor data streaming without the response pipeline (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - disaster-response
  - emergency
  - public-safety
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

# Disaster Response Setup

Deploy 4 agents: sensor-hub, coordinator, resource-allocator, and comms.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| sensor-hub | `<prefix>-sensor-hub` | pilot-stream-data, pilot-metrics, pilot-gossip | Aggregates weather, seismic, and flood sensor feeds |
| coordinator | `<prefix>-coordinator` | pilot-task-router, pilot-consensus, pilot-audit-log | Assesses severity, activates response protocols |
| resource-allocator | `<prefix>-resource-allocator` | pilot-dataset, pilot-event-filter, pilot-escrow | Manages supplies, vehicles, personnel deployment |
| comms | `<prefix>-comms` | pilot-announce, pilot-slack-bridge, pilot-webhook-bridge | Broadcasts alerts, coordinates with agencies |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For sensor-hub:
clawhub install pilot-stream-data pilot-metrics pilot-gossip
# For coordinator:
clawhub install pilot-task-router pilot-consensus pilot-audit-log
# For resource-allocator:
clawhub install pilot-dataset pilot-event-filter pilot-escrow
# For comms:
clawhub install pilot-announce pilot-slack-bridge pilot-webhook-bridge
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/disaster-response.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

**Step 5:** Verify connectivity with `pilotctl --json trust`.

## Manifest Templates Per Role

### sensor-hub
```json
{"setup":"disaster-response","role":"sensor-hub","role_name":"Sensor Hub","hostname":"<prefix>-sensor-hub","skills":{"pilot-stream-data":"Ingest feeds from weather stations, seismic sensors, and flood gauges.","pilot-metrics":"Track environmental thresholds and anomaly detection rates.","pilot-gossip":"Share sensor health and coverage status across hub nodes."},"data_flows":[{"direction":"send","peer":"<prefix>-coordinator","port":1002,"topic":"disaster-alert","description":"Disaster alerts with severity and location"}],"handshakes_needed":["<prefix>-coordinator"]}
```

### coordinator
```json
{"setup":"disaster-response","role":"coordinator","role_name":"Response Coordinator","hostname":"<prefix>-coordinator","skills":{"pilot-task-router":"Route response tasks to appropriate teams by type and location.","pilot-consensus":"Coordinate multi-agency response decisions.","pilot-audit-log":"Log all response decisions for post-incident review."},"data_flows":[{"direction":"receive","peer":"<prefix>-sensor-hub","port":1002,"topic":"disaster-alert","description":"Disaster alerts from sensor hub"},{"direction":"send","peer":"<prefix>-resource-allocator","port":1002,"topic":"resource-request","description":"Resource requests with priority"},{"direction":"send","peer":"<prefix>-comms","port":1002,"topic":"public-alert","description":"Public alerts with instructions"}],"handshakes_needed":["<prefix>-sensor-hub","<prefix>-resource-allocator","<prefix>-comms"]}
```

### resource-allocator
```json
{"setup":"disaster-response","role":"resource-allocator","role_name":"Resource Allocator","hostname":"<prefix>-resource-allocator","skills":{"pilot-dataset":"Store inventory of supplies, vehicles, and personnel availability.","pilot-event-filter":"Filter requests by priority and match to available resources.","pilot-escrow":"Hold resource reservations until deployment is confirmed."},"data_flows":[{"direction":"receive","peer":"<prefix>-coordinator","port":1002,"topic":"resource-request","description":"Resource requests from coordinator"},{"direction":"send","peer":"<prefix>-comms","port":1002,"topic":"deployment-status","description":"Deployment status and resource availability"}],"handshakes_needed":["<prefix>-coordinator","<prefix>-comms"]}
```

### comms
```json
{"setup":"disaster-response","role":"comms","role_name":"Communications Hub","hostname":"<prefix>-comms","skills":{"pilot-announce":"Broadcast emergency alerts to all subscribed channels.","pilot-slack-bridge":"Send coordination updates to agency Slack channels.","pilot-webhook-bridge":"Push alerts to external emergency broadcast systems."},"data_flows":[{"direction":"receive","peer":"<prefix>-coordinator","port":1002,"topic":"public-alert","description":"Public alerts from coordinator"},{"direction":"receive","peer":"<prefix>-resource-allocator","port":1002,"topic":"deployment-status","description":"Deployment updates from allocator"}],"handshakes_needed":["<prefix>-coordinator","<prefix>-resource-allocator"]}
```

## Data Flows

- `sensor-hub -> coordinator` : disaster alerts with severity and geographic data (port 1002)
- `coordinator -> resource-allocator` : resource requests with priority and location (port 1002)
- `coordinator -> comms` : public alerts with severity and instructions (port 1002)
- `resource-allocator -> comms` : deployment status and resource availability (port 1002)

## Handshakes

```bash
pilotctl --json handshake <prefix>-coordinator "setup: disaster-response"
pilotctl --json handshake <prefix>-sensor-hub "setup: disaster-response"
pilotctl --json handshake <prefix>-resource-allocator "setup: disaster-response"
pilotctl --json handshake <prefix>-comms "setup: disaster-response"
```

## Workflow Example

```bash
# On sensor-hub -- publish disaster alert:
pilotctl --json publish <prefix>-coordinator disaster-alert '{"type":"flood","severity":"high","location":"houston-metro","confidence":0.94}'
# On coordinator -- request resources:
pilotctl --json publish <prefix>-resource-allocator resource-request '{"incident_id":"INC-2841","type":"flood","teams_needed":12,"priority":"critical"}'
# On coordinator -- broadcast public alert:
pilotctl --json publish <prefix>-comms public-alert '{"incident_id":"INC-2841","severity":"high","message":"Flash flood warning. Seek higher ground."}'
# On resource-allocator -- report deployment:
pilotctl --json publish <prefix>-comms deployment-status '{"incident_id":"INC-2841","teams_deployed":8,"eta_min":45}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
