---
name: pilot-load-balancer
description: >
  Distribute tasks across worker pools with health-aware load balancing.

  Use this skill when:
  1. You need to distribute tasks across multiple worker agents
  2. You want round-robin, least-connections, or health-based routing
  3. You need to track worker capacity and avoid overload

  Do NOT use this skill when:
  - You need map-reduce parallelism (use pilot-map-reduce)
  - Workers should pull tasks themselves (use task queues)
tags:
  - pilot-protocol
  - load-balancing
  - task-distribution
  - coordination
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

# pilot-load-balancer

Implement load balancing strategies to distribute tasks across worker pools.

## Commands

### Discover available workers
```bash
WORKERS=$(pilotctl --json peers --search "role:worker" | jq -r '[.[] | {address, node_id, tags}]')
```

### Assign task using round-robin
```bash
ROBIN_INDEX=$(cat /tmp/load-balancer-index.txt 2>/dev/null || echo 0)
NEXT_WORKER=$(echo "$WORKERS" | jq -r ".[$ROBIN_INDEX].address")

pilotctl --json send-message "$NEXT_WORKER" \
  --data "{\"type\":\"task_assignment\",\"task_id\":\"$TASK_ID\"}"

echo "$(( (ROBIN_INDEX + 1) % WORKER_COUNT ))" > /tmp/load-balancer-index.txt
```

### Assign task using least-connections
```bash
LEAST_LOADED=$(echo "$WORKER_STATUS" | jq -r 'sort_by(.active_tasks) | first | .worker')

pilotctl --json send-message "$LEAST_LOADED" \
  --data "{\"type\":\"task_assignment\",\"task_id\":\"$TASK_ID\"}"
```

## Workflow Example

Distribute 10 tasks across 3 workers:

```bash
#!/bin/bash
WORKERS=$(pilotctl --json peers --search "pool:compute-workers" | jq -r '.[].address')
WORKER_ARRAY=($WORKERS)

ROBIN_INDEX=0

for i in {1..10}; do
  WORKER=${WORKER_ARRAY[$ROBIN_INDEX]}
  ROBIN_INDEX=$(( (ROBIN_INDEX + 1) % ${#WORKER_ARRAY[@]} ))

  pilotctl --json send-message "$WORKER" \
    --data "{\"type\":\"task_assignment\",\"task_id\":\"task-$i\"}" &
done
wait
```

## Dependencies

Requires pilot-protocol skill, jq, and uuidgen.
