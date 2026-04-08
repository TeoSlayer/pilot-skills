---
name: pilot-task-chain
description: >
  Chain tasks into sequential pipelines across agents.

  Use this skill when:
  1. You need multi-step workflows where each step depends on previous results
  2. You want to compose complex operations from simple agent capabilities
  3. You need to route intermediate results between different specialized agents

  Do NOT use this skill when:
  - Tasks can run independently in parallel
  - You don't need intermediate results passed between steps
  - A single agent can handle the entire workflow
tags:
  - pilot-protocol
  - task-workflow
  - pipeline
  - orchestration
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

# pilot-task-chain

Chain tasks into sequential pipelines where each step's output becomes the next step's input.

## Commands

### Submit first task
```bash
pilotctl --json task submit "$AGENT_1" --task "Fetch data from https://api.example.com/data"
```

### Wait for completion
```bash
TASK_ID="abc123"
while true; do
  STATUS=$(pilotctl --json task list --type submitted | jq -r ".[] | select(.task_id == \"$TASK_ID\") | .status")
  [ "$STATUS" == "completed" ] && break
  sleep 2
done
```

### Extract result and submit next task
```bash
RESULT=$(pilotctl --json task list --type submitted | jq -r ".[] | select(.task_id == \"$TASK_ID\") | .result")

pilotctl --json task submit "$AGENT_2" --task "Transform data: $RESULT"
```

## Workflow Example

Three-step pipeline (Fetch -> Transform -> Store):

```bash
#!/bin/bash
# Step 1: Fetch
FETCH_TASK=$(pilotctl --json task submit "$FETCH_AGENT" \
  --task "Fetch data from API endpoint")
FETCH_TASK_ID=$(echo "$FETCH_TASK" | jq -r '.task_id')

while [ "$(pilotctl --json task list --type submitted | jq -r ".[] | select(.task_id == \"$FETCH_TASK_ID\") | .status")" != "completed" ]; do
  sleep 2
done

FETCH_RESULT=$(pilotctl --json task list --type submitted | jq -r ".[] | select(.task_id == \"$FETCH_TASK_ID\") | .result")

# Step 2: Transform
TRANSFORM_TASK=$(pilotctl --json task submit "$TRANSFORM_AGENT" \
  --task "Transform data: $FETCH_RESULT")
TRANSFORM_TASK_ID=$(echo "$TRANSFORM_TASK" | jq -r '.task_id')

while [ "$(pilotctl --json task list --type submitted | jq -r ".[] | select(.task_id == \"$TRANSFORM_TASK_ID\") | .status")" != "completed" ]; do
  sleep 2
done

TRANSFORM_RESULT=$(pilotctl --json task list --type submitted | jq -r ".[] | select(.task_id == \"$TRANSFORM_TASK_ID\") | .result")

# Step 3: Store
STORE_TASK=$(pilotctl --json task submit "$STORE_AGENT" \
  --task "Store data: $TRANSFORM_RESULT")

echo "Pipeline completed: $(echo "$STORE_TASK" | jq -r '.task_id')"
```

## Dependencies

Requires pilot-protocol skill, jq, and multiple agents with complementary capabilities.
