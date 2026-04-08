---
name: pilot-workflow
description: >
  YAML-defined multi-step workflows with orchestration.

  Use this skill when:
  1. You need complex multi-step workflows with conditional logic
  2. You want declarative workflow definitions for reuse
  3. You need event-driven orchestration across multiple agents

  Do NOT use this skill when:
  - Simple linear task chains are sufficient (use pilot-task-chain)
  - Workflows don't have conditional branches or loops
  - You prefer imperative scripting over declarative YAML
tags:
  - pilot-protocol
  - task-workflow
  - orchestration
  - yaml
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

# pilot-workflow

YAML-defined multi-step workflows with advanced orchestration capabilities. Enables declarative workflow specifications with conditional branching, loops, parallel execution, and event-driven triggers.

## Commands

### Define workflow YAML

```yaml
name: data-pipeline
version: 1.0

triggers:
  - type: schedule
    cron: "0 */6 * * *"

steps:
  - id: fetch
    agent: tag:api-gateway
    task: "Fetch data from https://api.example.com/data"

  - id: validate
    depends_on: fetch
    agent: tag:validator
    task: "Validate data structure and integrity"

  - id: transform
    depends_on: validate
    condition: "${validate.result.valid} == true"
    agent: tag:etl
    task: "Transform data to parquet format"
```

### Execute workflow

```bash
./pilot-workflow-engine.sh workflow.yaml
```

### Monitor workflow

```bash
pilotctl --json task list --type submitted | \
  jq -r '.[] | select(.metadata.workflow_id == "data-pipeline-001")'
```

## Workflow Example

Complete workflow engine:

```bash
#!/bin/bash
# Pilot workflow engine - execute YAML-defined workflows

WORKFLOW_FILE=$1
WORKFLOW_NAME=$(yq eval '.name' "$WORKFLOW_FILE")
WORKFLOW_ID="${WORKFLOW_NAME}-$(date +%s)"
STEP_COUNT=$(yq eval '.steps | length' "$WORKFLOW_FILE")

echo "Workflow: $WORKFLOW_NAME ($STEP_COUNT steps)"

declare -A STEP_RESULTS
declare -A STEP_STATUS

# Execute each step
for ((STEP_IDX=0; STEP_IDX<STEP_COUNT; STEP_IDX++)); do
  STEP=$(yq eval ".steps[$STEP_IDX]" "$WORKFLOW_FILE")

  STEP_ID=$(echo "$STEP" | yq eval '.id' -)
  STEP_AGENT=$(echo "$STEP" | yq eval '.agent' -)
  STEP_TASK=$(echo "$STEP" | yq eval '.task' -)

  echo "Step $((STEP_IDX + 1)): $STEP_ID"

  # Find agent by tag
  if [[ $STEP_AGENT == tag:* ]]; then
    TAG=$(echo "$STEP_AGENT" | cut -d: -f2)
    AGENT=$(pilotctl --json peers --search "$TAG" | \
      jq -r 'sort_by(-.polo_score) | .[0].address')
  else
    AGENT="$STEP_AGENT"
  fi

  # Submit task
  TASK_RESULT=$(pilotctl --json task submit "$AGENT" --task "$STEP_TASK")

  TASK_ID=$(echo "$TASK_RESULT" | jq -r '.task_id')

  # Wait for completion
  while true; do
    STATUS=$(pilotctl --json task list --type submitted | \
      jq -r ".[] | select(.task_id == \"$TASK_ID\") | .status")

    if [ "$STATUS" == "completed" ]; then
      STEP_STATUS[$STEP_ID]="completed"
      RESULT=$(pilotctl --json task list --type submitted | \
        jq -r ".[] | select(.task_id == \"$TASK_ID\") | .result")
      STEP_RESULTS[$STEP_ID]="$RESULT"
      break
    fi
    sleep 2
  done
done

echo "Workflow completed: $WORKFLOW_ID"
```

## Dependencies

Requires pilot-protocol skill with running daemon, jq for JSON parsing, yq for YAML parsing (brew install yq), and Bash 4.0+ for associative arrays.
