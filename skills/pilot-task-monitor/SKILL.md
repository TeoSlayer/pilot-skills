---
name: pilot-task-monitor
description: >
  Real-time dashboard for task status and polo score tracking.

  Use this skill when:
  1. You need to monitor active tasks across multiple agents
  2. You want real-time updates on task status and polo score changes
  3. You need a dashboard view of task queue and completion metrics

  Do NOT use this skill when:
  - You only need to check a single task status once
  - You don't need continuous monitoring
  - You prefer event-based notifications over polling
tags:
  - pilot-protocol
  - task-workflow
  - monitoring
  - dashboard
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

# pilot-task-monitor

Real-time monitoring dashboard for task execution and polo score tracking.

## Commands

### List all submitted tasks
```bash
pilotctl --json task list --type submitted | jq -r '.[] | "\(.task_id) -> \(.target) [\(.status)]"'
```

### List incoming task queue
```bash
pilotctl --json task queue | jq -r '.[] | "\(.task_id) from \(.requester) [\(.type)]"'
```

### Track polo score
```bash
watch -n 5 "pilotctl --json info | jq -r '.polo_score'"
```

### Dashboard summary
```bash
pilotctl --json task list --type submitted | jq '{
  total: length,
  pending: [.[] | select(.status == "pending")] | length,
  completed: [.[] | select(.status == "completed")] | length,
  failed: [.[] | select(.status == "failed")] | length
}'
```

## Workflow Example

Continuous task monitoring dashboard:

```bash
#!/bin/bash
while true; do
  clear
  echo "=== PILOT TASK MONITOR ==="

  POLO=$(pilotctl --json info | jq -r '.polo_score // 0')
  echo "Polo Score: $POLO"

  SUBMITTED=$(pilotctl --json task list --type submitted)
  TOTAL=$(echo "$SUBMITTED" | jq 'length')
  PENDING=$(echo "$SUBMITTED" | jq '[.[] | select(.status == "pending")] | length')
  COMPLETED=$(echo "$SUBMITTED" | jq '[.[] | select(.status == "completed")] | length')

  echo "Total: $TOTAL | Pending: $PENDING | Completed: $COMPLETED"

  sleep 3
done
```

## Dependencies

Requires pilot-protocol skill, jq, and watch.
