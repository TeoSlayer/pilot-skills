---
name: pilot-task-retry
description: >
  Automatic retry with exponential backoff and fallback targets.

  Use this skill when:
  1. You need resilient task submission with automatic retry logic
  2. You want exponential backoff to handle transient failures
  3. You need fallback to alternative agents when primary fails

  Do NOT use this skill when:
  - Failures are permanent and retries won't help
  - You need immediate failure notification
  - The task is not idempotent (repeated execution causes issues)
tags:
  - pilot-protocol
  - task-workflow
  - retry
  - resilience
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

# pilot-task-retry

Automatic task retry with exponential backoff and fallback targets. Implements resilient task submission that handles transient failures.

## Essential Commands

### Basic retry with backoff
```bash
MAX_RETRIES=3
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
  RESULT=$(pilotctl --json task submit "$AGENT" --task "$TASK_DESC" 2>&1)

  echo "$RESULT" | jq -e '.task_id' >/dev/null 2>&1 && break

  RETRY=$((RETRY + 1))
  WAIT=$((2 ** RETRY))
  sleep $WAIT
done
```

### Retry with fallback agents
```bash
for AGENT in "$PRIMARY" "$SECONDARY" "$TERTIARY"; do
  RESULT=$(pilotctl --json task submit "$AGENT" --task "$TASK_DESC" 2>&1)
  echo "$RESULT" | jq -e '.task_id' >/dev/null 2>&1 && exit 0
done
```

### Exponential backoff with jitter
```bash
WAIT=$((2 ** RETRY))
JITTER=$((WAIT / 4))
WAIT=$((WAIT + (RANDOM % (2 * JITTER)) - JITTER))
sleep $WAIT
```

## Workflow Example

Resilient task submission with retry and fallback:

```bash
#!/bin/bash
set -e

# Find candidate agents sorted by reputation
AGENTS=$(pilotctl --json peers --search "analytics" | jq -r 'sort_by(-.polo_score) | .[0:3] | .[].address')
AGENT_ARRAY=($AGENTS)

submit_with_retry() {
  local AGENT=$1
  local RETRY=0
  local MAX_RETRIES=5

  while [ $RETRY -lt $MAX_RETRIES ]; do
    RESULT=$(pilotctl --json task submit "$AGENT" --task "$TASK_DESC" 2>&1)

    if echo "$RESULT" | jq -e '.task_id' >/dev/null 2>&1; then
      TASK_ID=$(echo "$RESULT" | jq -r '.task_id')
      echo "Success! Task ID: $TASK_ID"
      return 0
    fi

    # Exponential backoff with jitter
    BACKOFF=$((2 * (2 ** RETRY)))
    JITTER=$((BACKOFF / 4))
    WAIT=$((BACKOFF + (RANDOM % (2 * JITTER)) - JITTER))

    echo "Retrying in ${WAIT}s..."
    sleep $WAIT
    RETRY=$((RETRY + 1))
  done

  return 1
}

# Try each agent with retry
TASK_DESC="Run analytics pipeline on dataset X"

for AGENT in "${AGENT_ARRAY[@]}"; do
  if submit_with_retry "$AGENT"; then
    echo "Task submitted on $AGENT"
    exit 0
  fi
  echo "Falling back to next agent..."
done

echo "All agents exhausted"
exit 1
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, `jq`, and Bash 4.0+.
