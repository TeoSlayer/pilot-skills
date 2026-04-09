# Multi-Region Content Sync Setup

Distribute content from a central origin to edge nodes across multiple regions. The origin broadcasts updates and edges sync automatically. Heartbeat monitoring ensures every edge is alive, with automatic alerting when a region goes dark.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### origin (Content Origin)
The source of truth for all content. Broadcasts updates to all edge nodes whenever content changes.

**Skills:** pilot-sync, pilot-share, pilot-broadcast

### edge-us (US Edge Node)
Serves content for the US region. Syncs from origin and reports health via heartbeats.

**Skills:** pilot-sync, pilot-share, pilot-health, pilot-heartbeat-monitor

### edge-eu (EU Edge Node)
Serves content for the EU region. Syncs from origin and reports health via heartbeats.

**Skills:** pilot-sync, pilot-share, pilot-health, pilot-heartbeat-monitor

### edge-asia (Asia Edge Node)
Serves content for the Asia region. Syncs from origin and reports health via heartbeats.

**Skills:** pilot-sync, pilot-share, pilot-health, pilot-heartbeat-monitor

## Data Flow

```
origin  --> edge-us   : Broadcasts content updates to US edge (port 1001)
origin  --> edge-eu   : Broadcasts content updates to EU edge (port 1001)
origin  --> edge-asia : Broadcasts content updates to Asia edge (port 1001)
edge-us   --> origin  : Heartbeat and sync confirmation (port 1002)
edge-eu   --> origin  : Heartbeat and sync confirmation (port 1002)
edge-asia --> origin  : Heartbeat and sync confirmation (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On origin server
clawhub install pilot-sync pilot-share pilot-broadcast
pilotctl set-hostname <your-prefix>-origin

# On US edge server
clawhub install pilot-sync pilot-share pilot-health pilot-heartbeat-monitor
pilotctl set-hostname <your-prefix>-edge-us

# On EU edge server
clawhub install pilot-sync pilot-share pilot-health pilot-heartbeat-monitor
pilotctl set-hostname <your-prefix>-edge-eu

# On Asia edge server
clawhub install pilot-sync pilot-share pilot-health pilot-heartbeat-monitor
pilotctl set-hostname <your-prefix>-edge-asia
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On edge-asia:
pilotctl handshake <your-prefix>-origin "setup: multi-region-content-sync"
# On origin:
pilotctl handshake <your-prefix>-edge-asia "setup: multi-region-content-sync"
# On edge-eu:
pilotctl handshake <your-prefix>-origin "setup: multi-region-content-sync"
# On origin:
pilotctl handshake <your-prefix>-edge-eu "setup: multi-region-content-sync"
# On edge-us:
pilotctl handshake <your-prefix>-origin "setup: multi-region-content-sync"
# On origin:
pilotctl handshake <your-prefix>-edge-us "setup: multi-region-content-sync"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-origin — broadcast a content update to all edges:
pilotctl send-file <your-prefix>-edge-us ./content/index.html
pilotctl send-file <your-prefix>-edge-eu ./content/index.html
pilotctl send-file <your-prefix>-edge-asia ./content/index.html
pilotctl publish <your-prefix>-edge-us content-update '{"file":"index.html","version":42,"hash":"sha256:a1b2c3"}'
pilotctl publish <your-prefix>-edge-eu content-update '{"file":"index.html","version":42,"hash":"sha256:a1b2c3"}'
pilotctl publish <your-prefix>-edge-asia content-update '{"file":"index.html","version":42,"hash":"sha256:a1b2c3"}'

# On any edge — confirm sync and send heartbeat:
pilotctl publish <your-prefix>-origin sync-complete '{"region":"us","file":"index.html","version":42}'
pilotctl publish <your-prefix>-origin heartbeat '{"region":"us","status":"healthy","disk_pct":34}'
```
