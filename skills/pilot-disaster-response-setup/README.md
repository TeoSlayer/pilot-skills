# Disaster Response

A multi-agent emergency management system that coordinates sensor aggregation, disaster assessment, resource allocation, and public communications across four specialized agents. The sensor hub aggregates feeds from weather stations, seismic sensors, flood gauges, and satellite imagery. The coordinator assesses disaster severity and activates response protocols. The resource allocator manages inventory of emergency supplies, vehicles, and personnel. The communications hub broadcasts public alerts and coordinates with agencies.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### sensor-hub (Sensor Hub)
Aggregates feeds from weather stations, seismic sensors, flood gauges, and satellite imagery. Normalizes multi-source environmental data into unified disaster alert objects with severity classification, geographic bounds, and confidence levels.

**Skills:** pilot-stream-data, pilot-metrics, pilot-gossip

### coordinator (Response Coordinator)
Assesses disaster severity, activates response protocols, assigns response teams. Correlates sensor data with predefined thresholds to determine disaster type, scale, and required response level. Manages the overall incident lifecycle.

**Skills:** pilot-task-router, pilot-consensus, pilot-audit-log

### resource-allocator (Resource Allocator)
Manages inventory of emergency supplies, vehicles, personnel. Optimizes deployment based on disaster location, severity, and available resources. Tracks resource consumption and requests resupply when thresholds are breached.

**Skills:** pilot-dataset, pilot-event-filter, pilot-escrow

### comms (Communications Hub)
Broadcasts alerts to public, coordinates with agencies, sends status updates to officials. Manages multi-channel communication across emergency broadcast systems, agency coordination channels, and public information feeds.

**Skills:** pilot-announce, pilot-slack-bridge, pilot-webhook-bridge

## Data Flow

```
sensor-hub         --> coordinator         : Disaster alerts with severity and geographic data (port 1002)
coordinator        --> resource-allocator  : Resource requests with priority and location (port 1002)
coordinator        --> comms               : Public alerts with severity and instructions (port 1002)
resource-allocator --> comms               : Deployment status and resource availability (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On sensor aggregation server
clawhub install pilot-stream-data pilot-metrics pilot-gossip
pilotctl set-hostname <your-prefix>-sensor-hub

# On coordination server
clawhub install pilot-task-router pilot-consensus pilot-audit-log
pilotctl set-hostname <your-prefix>-coordinator

# On resource management server
clawhub install pilot-dataset pilot-event-filter pilot-escrow
pilotctl set-hostname <your-prefix>-resource-allocator

# On communications server
clawhub install pilot-announce pilot-slack-bridge pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-comms
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# sensor-hub <-> coordinator (disaster alerts)
# On sensor-hub:
pilotctl handshake <your-prefix>-coordinator "setup: disaster-response"
# On coordinator:
pilotctl handshake <your-prefix>-sensor-hub "setup: disaster-response"

# coordinator <-> resource-allocator (resource requests)
# On coordinator:
pilotctl handshake <your-prefix>-resource-allocator "setup: disaster-response"
# On resource-allocator:
pilotctl handshake <your-prefix>-coordinator "setup: disaster-response"

# coordinator <-> comms (public alerts)
# On coordinator:
pilotctl handshake <your-prefix>-comms "setup: disaster-response"
# On comms:
pilotctl handshake <your-prefix>-coordinator "setup: disaster-response"

# resource-allocator <-> comms (deployment status)
# On resource-allocator:
pilotctl handshake <your-prefix>-comms "setup: disaster-response"
# On comms:
pilotctl handshake <your-prefix>-resource-allocator "setup: disaster-response"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-sensor-hub -- publish a disaster alert:
pilotctl publish <your-prefix>-coordinator disaster-alert '{"type":"flood","severity":"high","location":{"lat":29.76,"lon":-95.37,"radius_km":25},"river_gauge_m":8.4,"threshold_m":7.0,"confidence":0.94,"timestamp":"2026-04-10T06:30:00Z"}'

# On <your-prefix>-coordinator -- publish a resource request:
pilotctl publish <your-prefix>-resource-allocator resource-request '{"incident_id":"INC-2841","type":"flood","severity":"high","location":"houston-metro","teams_needed":12,"supplies":["sandbags","pumps","boats"],"priority":"critical"}'

# On <your-prefix>-coordinator -- publish a public alert:
pilotctl publish <your-prefix>-comms public-alert '{"incident_id":"INC-2841","type":"flood","severity":"high","message":"Flash flood warning for Houston metro area. Seek higher ground immediately.","channels":["eas","sms","web"]}'

# On <your-prefix>-resource-allocator -- publish deployment status:
pilotctl publish <your-prefix>-comms deployment-status '{"incident_id":"INC-2841","teams_deployed":8,"teams_en_route":4,"supplies_dispatched":{"sandbags":5000,"pumps":24,"boats":12},"eta_min":45}'
```
