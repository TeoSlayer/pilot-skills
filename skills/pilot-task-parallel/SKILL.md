---
name: pilot-task-parallel
description: >
  Fan-out tasks to multiple agents and merge results.

  Use this skill when:
  1. You need to distribute independent work across multiple agents
  2. You want to aggregate results from parallel task execution
  3. You need to reduce execution time through parallelization

  Do NOT use this skill when:
  - Tasks have sequential dependencies (use pilot-task-chain)
  - You only need to run a single task
  - Order of execution matters for correctness
tags:
  - pilot-protocol
  - task-workflow
  - parallel
  - fan-out
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

# pilot-task-parallel

Fan-out tasks to multiple agents for parallel execution and merge results.

## Commands

### Submit multiple tasks in parallel
```bash
for AGENT in "${AGENTS[@]}"; do
  pilotctl --json task submit "$AGENT" --task "Compute task batch" &
done
wait
```

### Wait for all completions
```bash
while true; do
  ALL_DONE=true
  for TASK_ID in "${TASK_IDS[@]}"; do
    STATUS=$(pilotctl --json task list --type submitted | jq -r ".[] | select(.task_id == \"$TASK_ID\") | .status")
    [ "$STATUS" != "completed" ] && [ "$STATUS" != "failed" ] && ALL_DONE=false && break
  done
  [ "$ALL_DONE" == true ] && break
  sleep 2
done
```

### Merge results
```bash
pilotctl --json task list --type submitted | \
  jq -r "[.[] | select(.task_id | IN(\"${TASK_IDS[@]}\")) | select(.status == \"completed\") | .result]"
```

## Workflow Example

Distribute image processing across GPU agents:

```bash
#!/bin/bash
GPU_AGENTS=$(pilotctl --json peers --search "gpu" | jq -r '.[].address')
AGENT_ARRAY=($GPU_AGENTS)

TASK_IDS=()
for i in {1..10}; do
  AGENT=${AGENT_ARRAY[$((i % ${#AGENT_ARRAY[@]}))]}
  TASK=$(pilotctl --json task submit "$AGENT" \
    --task "Process image batch index $i")
  TASK_IDS+=("$(echo "$TASK" | jq -r '.task_id')")
done

# Wait for all tasks
while true; do
  ALL_DONE=true
  for TASK_ID in "${TASK_IDS[@]}"; do
    STATUS=$(pilotctl --json task list --type submitted | \
      jq -r ".[] | select(.task_id == \"$TASK_ID\") | .status")
    [ "$STATUS" != "completed" ] && [ "$STATUS" != "failed" ] && ALL_DONE=false && break
  done
  [ "$ALL_DONE" == true ] && break
  sleep 2
done

echo "All tasks completed"
```

## Dependencies

Requires pilot-protocol skill, jq, and Bash 4.0+.
