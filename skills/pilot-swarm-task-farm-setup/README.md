# Swarm Task Farm Setup

A self-organizing compute swarm. Workers join automatically, a leader is elected via consensus, and tasks are distributed using map-reduce. Failed tasks retry automatically. A monitor agent tracks swarm health and reports to Slack.

**Difficulty:** Advanced | **Agents:** 5

## Roles

### leader (Swarm Leader)
Elected via consensus. Accepts incoming tasks, partitions them using map-reduce, and broadcasts work units to workers. Re-election happens automatically if the leader goes down.

**Skills:** pilot-leader-election, pilot-formation, pilot-task-router, pilot-broadcast

### worker-1 (Compute Worker)
Joins the swarm, receives work units, executes tasks, and returns results. Retries failed tasks automatically.

**Skills:** pilot-swarm-join, pilot-map-reduce, pilot-task-retry, pilot-metrics

### worker-2 (Compute Worker)
Joins the swarm, receives work units, executes tasks, and returns results. Retries failed tasks automatically.

**Skills:** pilot-swarm-join, pilot-map-reduce, pilot-task-retry, pilot-metrics

### worker-3 (Compute Worker)
Joins the swarm, receives work units, executes tasks, and returns results. Retries failed tasks automatically.

**Skills:** pilot-swarm-join, pilot-map-reduce, pilot-task-retry, pilot-metrics

### monitor (Swarm Monitor)
Tracks which workers are alive, task completion rates, and queue depth. Alerts on worker failures or stalled tasks.

**Skills:** pilot-task-monitor, pilot-mesh-status, pilot-slack-bridge, pilot-metrics

## Data Flow

```
leader   --> worker-1 : Distributes work units via map-reduce (port 1002)
leader   --> worker-2 : Distributes work units via map-reduce (port 1002)
leader   --> worker-3 : Distributes work units via map-reduce (port 1002)
worker-1 --> leader   : Returns completed results (port 1002)
worker-2 --> leader   : Returns completed results (port 1002)
worker-3 --> leader   : Returns completed results (port 1002)
worker-1 --> monitor  : Reports task metrics and heartbeats (port 1002)
worker-2 --> monitor  : Reports task metrics and heartbeats (port 1002)
worker-3 --> monitor  : Reports task metrics and heartbeats (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On leader node
clawhub install pilot-leader-election pilot-formation pilot-task-router pilot-broadcast
pilotctl set-hostname <your-prefix>-leader

# On each worker node (repeat for worker-1, worker-2, worker-3)
clawhub install pilot-swarm-join pilot-map-reduce pilot-task-retry pilot-metrics
pilotctl set-hostname <your-prefix>-worker-1

# On monitor node
clawhub install pilot-task-monitor pilot-mesh-status pilot-slack-bridge pilot-metrics
pilotctl set-hostname <your-prefix>-monitor
```

### 2. Establish trust

Each worker must handshake the leader and monitor. The leader must handshake all workers and the monitor. When both sides handshake, trust is auto-approved.

```bash
# On leader:
pilotctl handshake <your-prefix>-worker-1 "swarm task farm"
pilotctl handshake <your-prefix>-worker-2 "swarm task farm"
pilotctl handshake <your-prefix>-worker-3 "swarm task farm"
pilotctl handshake <your-prefix>-monitor "swarm task farm"

# On worker-1:
pilotctl handshake <your-prefix>-leader "swarm task farm"
pilotctl handshake <your-prefix>-monitor "swarm task farm"

# On worker-2:
pilotctl handshake <your-prefix>-leader "swarm task farm"
pilotctl handshake <your-prefix>-monitor "swarm task farm"

# On worker-3:
pilotctl handshake <your-prefix>-leader "swarm task farm"
pilotctl handshake <your-prefix>-monitor "swarm task farm"

# On monitor:
pilotctl handshake <your-prefix>-leader "swarm task farm"
pilotctl handshake <your-prefix>-worker-1 "swarm task farm"
pilotctl handshake <your-prefix>-worker-2 "swarm task farm"
pilotctl handshake <your-prefix>-worker-3 "swarm task farm"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-leader — distribute tasks to workers:
pilotctl publish <your-prefix>-worker-1 task-assignment '{"task_id":"T-001","type":"image_resize","input":"batch-a.zip"}'
pilotctl publish <your-prefix>-worker-2 task-assignment '{"task_id":"T-002","type":"image_resize","input":"batch-b.zip"}'
pilotctl publish <your-prefix>-worker-3 task-assignment '{"task_id":"T-003","type":"image_resize","input":"batch-c.zip"}'

# On <your-prefix>-worker-1 — complete and report:
pilotctl publish <your-prefix>-leader task-result '{"task_id":"T-001","status":"success","output":"batch-a-resized.zip","duration_s":34}'
pilotctl publish <your-prefix>-monitor worker-metrics '{"worker":"worker-1","cpu":72,"tasks_done":15,"queue":0}'

# On <your-prefix>-monitor — check swarm health:
pilotctl subscribe <your-prefix>-worker-1 worker-metrics
pilotctl subscribe <your-prefix>-worker-2 worker-metrics
pilotctl subscribe <your-prefix>-worker-3 worker-metrics
```
