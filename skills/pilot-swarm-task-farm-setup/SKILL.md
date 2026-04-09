---
name: pilot-swarm-task-farm-setup
description: >
  Deploy a self-organizing compute swarm with 5 agents.

  Use this skill when:
  1. User wants to set up a distributed task farm or compute swarm
  2. User is configuring a leader, worker, or monitor agent
  3. User asks about leader election, map-reduce, or swarm coordination

  Do NOT use this skill when:
  - User wants to submit a single task (use pilot-task-router instead)
  - User wants leader election only (use pilot-leader-election instead)
tags:
  - pilot-protocol
  - setup
  - swarm
  - distributed-compute
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

# Swarm Task Farm Setup

Deploy 5 agents: 1 leader, 3 workers, and 1 monitor.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| leader | `<prefix>-leader` | pilot-leader-election, pilot-formation, pilot-task-router, pilot-broadcast | Elected leader, distributes tasks |
| worker-N | `<prefix>-worker-N` | pilot-swarm-join, pilot-map-reduce, pilot-task-retry, pilot-metrics | Executes tasks, retries on failure |
| monitor | `<prefix>-monitor` | pilot-task-monitor, pilot-mesh-status, pilot-slack-bridge, pilot-metrics | Tracks swarm health |

## Setup Procedure

**Step 1:** Ask the user which role and prefix. For workers, also ask the worker number (1, 2, or 3).

**Step 2:** Install skills:
```bash
# leader:
clawhub install pilot-leader-election pilot-formation pilot-task-router pilot-broadcast
# worker (repeat for each):
clawhub install pilot-swarm-join pilot-map-reduce pilot-task-retry pilot-metrics
# monitor:
clawhub install pilot-task-monitor pilot-mesh-status pilot-slack-bridge pilot-metrics
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/swarm-task-farm.json`.

**Step 4:** Handshake — workers trust leader + monitor; leader trusts all workers + monitor.

## Manifest Templates Per Role

### leader
```json
{
  "setup": "swarm-task-farm", "role": "leader", "role_name": "Swarm Leader",
  "hostname": "<prefix>-leader",
  "skills": {
    "pilot-leader-election": "Participate in leader election via consensus.",
    "pilot-formation": "Manage swarm membership.",
    "pilot-task-router": "Partition and distribute tasks to workers.",
    "pilot-broadcast": "Broadcast work units to all workers."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-worker-1", "port": 1002, "topic": "task-assignment", "description": "Work units" },
    { "direction": "send", "peer": "<prefix>-worker-2", "port": 1002, "topic": "task-assignment", "description": "Work units" },
    { "direction": "send", "peer": "<prefix>-worker-3", "port": 1002, "topic": "task-assignment", "description": "Work units" },
    { "direction": "receive", "peer": "<prefix>-worker-1", "port": 1002, "topic": "task-result", "description": "Completed results" },
    { "direction": "receive", "peer": "<prefix>-worker-2", "port": 1002, "topic": "task-result", "description": "Completed results" },
    { "direction": "receive", "peer": "<prefix>-worker-3", "port": 1002, "topic": "task-result", "description": "Completed results" }
  ],
  "handshakes_needed": ["<prefix>-worker-1", "<prefix>-worker-2", "<prefix>-worker-3", "<prefix>-monitor"]
}
```

### worker-N
```json
{
  "setup": "swarm-task-farm", "role": "worker-N", "role_name": "Compute Worker",
  "hostname": "<prefix>-worker-N",
  "skills": {
    "pilot-swarm-join": "Join the swarm and register with leader.",
    "pilot-map-reduce": "Execute map-reduce work units.",
    "pilot-task-retry": "Retry failed tasks with exponential backoff.",
    "pilot-metrics": "Report CPU, memory, task throughput to monitor."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-leader", "port": 1002, "topic": "task-assignment", "description": "Work units" },
    { "direction": "send", "peer": "<prefix>-leader", "port": 1002, "topic": "task-result", "description": "Completed results" },
    { "direction": "send", "peer": "<prefix>-monitor", "port": 1002, "topic": "worker-metrics", "description": "Health metrics" }
  ],
  "handshakes_needed": ["<prefix>-leader", "<prefix>-monitor"]
}
```

### monitor
```json
{
  "setup": "swarm-task-farm", "role": "monitor", "role_name": "Swarm Monitor",
  "hostname": "<prefix>-monitor",
  "skills": {
    "pilot-task-monitor": "Track task completion rates and queue depth.",
    "pilot-mesh-status": "Monitor worker connectivity and latency.",
    "pilot-slack-bridge": "Alert on worker failures or stalled tasks.",
    "pilot-metrics": "Aggregate and display swarm metrics."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-worker-1", "port": 1002, "topic": "worker-metrics", "description": "Worker health" },
    { "direction": "receive", "peer": "<prefix>-worker-2", "port": 1002, "topic": "worker-metrics", "description": "Worker health" },
    { "direction": "receive", "peer": "<prefix>-worker-3", "port": 1002, "topic": "worker-metrics", "description": "Worker health" }
  ],
  "handshakes_needed": ["<prefix>-leader", "<prefix>-worker-1", "<prefix>-worker-2", "<prefix>-worker-3"]
}
```

## Data Flows

- `leader → worker-*` : task assignments (port 1002)
- `worker-* → leader` : completed results (port 1002)
- `worker-* → monitor` : health metrics (port 1002)

## Workflow Example

```bash
# On leader — distribute:
pilotctl --json publish <prefix>-worker-1 task-assignment '{"task_id":"T-001","type":"image_resize","input":"batch-a.zip"}'
# On worker-1 — complete:
pilotctl --json publish <prefix>-leader task-result '{"task_id":"T-001","status":"success","duration_s":34}'
pilotctl --json publish <prefix>-monitor worker-metrics '{"worker":"worker-1","cpu":72,"tasks_done":15}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
