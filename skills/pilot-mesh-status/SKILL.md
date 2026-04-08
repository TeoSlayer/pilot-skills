---
name: pilot-mesh-status
description: >
  Comprehensive mesh status — peers, encryption, relay, bandwidth.

  Use this skill when:
  1. Getting a complete overview of network status and health
  2. Debugging connectivity or performance issues across the mesh
  3. Generating status reports for monitoring or dashboards

  Do NOT use this skill when:
  - You only need peer discovery (use pilot-discover instead)
  - You need detailed health monitoring (use pilot-health instead)
  - You need to visualize topology (use pilot-network-map instead)
tags:
  - pilot-protocol
  - status
  - monitoring
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# pilot-mesh-status

Comprehensive mesh network status reporting for Pilot Protocol. Aggregates daemon health, peer status, encryption state, relay usage, bandwidth metrics, and connection details into unified reports.

## Commands

### List All Peers
```bash
pilotctl --json peers
```

### List Active Connections
```bash
pilotctl --json connections
```

### Get Agent Info
```bash
pilotctl --json info
```

### Benchmark Connection
```bash
pilotctl --json bench <node-id>
```

### Check Daemon Status
```bash
pilotctl --json daemon status
```

## Status Dimensions

A complete mesh status report covers:
1. **Daemon health**: Uptime, resource usage, error rate
2. **Network membership**: Peer count, discovery status
3. **Connections**: Active connections, ports, encryption
4. **Trust**: Trust relationships, mutual trust count
5. **Relay usage**: Relay vs direct connections
6. **Bandwidth**: Total bytes sent/received
7. **Latency**: RTT to key peers
8. **Security**: Encryption coverage, trust coverage

## Workflow Example

Generate comprehensive mesh status report:

```bash
#!/bin/bash
echo "========== PILOT MESH STATUS =========="
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Daemon Health
daemon_status=$(pilotctl --json daemon status)
echo "$daemon_status" | jq -r '
  "Uptime: \(.uptime_seconds)s",
  "Memory: \(.memory_mb)MB",
  "Connections: \(.connection_count)"'

# Network Membership
peers=$(pilotctl --json peers)
peer_count=$(echo "$peers" | jq '.peers | length')
echo "Total peers: $peer_count"

# Active Connections
connections=$(pilotctl --json connections)
conn_count=$(echo "$connections" | jq '.connections | length')
echo "Total connections: $conn_count"

# Relay Usage
relay_count=$(echo "$connections" | jq '[.connections[] | select(.relay)] | length')
direct_count=$((conn_count - relay_count))
echo "Direct: $direct_count, Relay: $relay_count"

# Bandwidth
total_sent=$(echo "$connections" | jq '[.connections[].bytes_sent] | add // 0')
total_recv=$(echo "$connections" | jq '[.connections[].bytes_received] | add // 0')
echo "Sent: $(numfmt --to=iec $total_sent)"
echo "Recv: $(numfmt --to=iec $total_recv)"

# Encryption Coverage
encrypted_count=$(echo "$connections" | jq '[.connections[] | select(.encrypted)] | length')
if [ "$conn_count" -gt 0 ]; then
  enc_pct=$(echo "scale=1; $encrypted_count * 100 / $conn_count" | bc)
  echo "Encrypted: $encrypted_count/$conn_count ($enc_pct%)"
fi
```

## Dependencies

Requires `pilot-protocol` skill and running daemon.
