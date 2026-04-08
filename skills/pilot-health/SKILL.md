---
name: pilot-health
description: >
  Network health monitoring with latency and reachability checks.

  Use this skill when:
  1. Diagnosing connectivity issues or high latency
  2. Monitoring network health and performance metrics
  3. Running continuous health checks for uptime monitoring

  Do NOT use this skill when:
  - You need to discover new agents (use pilot-discover instead)
  - You need to visualize topology (use pilot-network-map instead)
  - You need to establish connections (use pilot-connect instead)
tags:
  - pilot-protocol
  - monitoring
  - health
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

# pilot-health

Network health monitoring for Pilot Protocol agents. Check connectivity, measure latency, diagnose routing issues, and monitor daemon health.

## Commands

### Ping an agent
```bash
pilotctl --json ping <node-id>
```
Sends ICMP-like echo requests and returns round-trip time statistics.

### Traceroute to agent
```bash
pilotctl --json traceroute <node-id>
```
Shows the path packets take through the network, including relay hops.

### Benchmark connection
```bash
pilotctl --json bench <node-id>
```
Measures throughput, latency under load, and connection stability.

### Check daemon status
```bash
pilotctl --json daemon status
```
Returns daemon health including uptime, memory usage, connection count.

### List active connections
```bash
pilotctl --json connections
```
Shows all active connections with state, ports, encryption status, and byte counts.

### List all peers
```bash
pilotctl --json peers
```
Returns known agents with last contact timestamp.

## Workflow Example

Diagnose why connections to a specific agent are slow:

```bash
# Check basic reachability
ping_result=$(pilotctl --json ping "ai-worker-01")
echo "$ping_result" | jq '{avg_rtt: .avg_rtt_ms, loss: .packet_loss_pct}'

# Identify relay hops
trace=$(pilotctl --json traceroute "ai-worker-01")
echo "$trace" | jq '.hops[] | {hop: .hop_num, node: .node_id, rtt: .rtt_ms}'

# Measure throughput
bench=$(pilotctl --json bench "ai-worker-01")
echo "$bench" | jq '{throughput_mbps: .throughput_mbps, latency_p99: .latency_p99_ms}'

# Check daemon health
pilotctl --json daemon status | jq '{uptime: .uptime_seconds, conn_count: .connection_count}'
```

## Dependencies

Requires the `pilot-protocol` core skill and a running daemon. Target agents must be reachable (may require trust for private agents).
