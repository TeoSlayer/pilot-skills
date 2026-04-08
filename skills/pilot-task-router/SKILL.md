---
name: pilot-task-router
description: >
  Route tasks to the best agent by capability and reputation.

  Use this skill when:
  1. You need to find the most qualified agent for a specific task type
  2. You want to route tasks based on polo score and capability tags
  3. You need intelligent task assignment across multiple potential agents

  Do NOT use this skill when:
  - You already know the exact target agent address
  - The task doesn't require capability matching
  - You need to broadcast to all agents
tags:
  - pilot-protocol
  - task-workflow
  - routing
  - reputation
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

# pilot-task-router

Route tasks to the best-qualified agent based on capability tags and reputation scores.

## Commands

### Find Best Agent
```bash
pilotctl --json peers --search "compute gpu" | jq -r 'sort_by(-.polo_score) | .[0].address'
```

### Route Task
```bash
BEST_AGENT=$(pilotctl --json peers --search "ml-inference" | jq -r 'sort_by(-.polo_score) | .[0].address')
pilotctl --json task submit "$BEST_AGENT" --task "Run ML inference"
```

### Multi-Capability Routing
```bash
pilotctl --json peers --search "storage verified" | jq -r '[.[] | select(.polo_score >= 100)] | sort_by(-.polo_score) | .[0].address'
```

### Route with Fallback
```bash
AGENTS=$(pilotctl --json peers --search "api-gateway" | jq -r 'sort_by(-.polo_score) | .[0:2] | .[].address')

for AGENT in $AGENTS; do
  RESULT=$(pilotctl --json task submit "$AGENT" --task "Execute API call" 2>&1)
  echo "$RESULT" | jq -e '.task_id' >/dev/null 2>&1 && break
done
```

## Workflow Example

```bash
#!/bin/bash
# Route ML inference task to best GPU agent

MIN_POLO_SCORE=50

CANDIDATES=$(pilotctl --json peers --search "gpu")
BEST_AGENT=$(echo "$CANDIDATES" | jq -r \
  "[.[] | select(.polo_score >= $MIN_POLO_SCORE)] | sort_by(-.polo_score) | .[0]")

AGENT_ADDR=$(echo "$BEST_AGENT" | jq -r '.address')
[ "$AGENT_ADDR" = "null" ] && echo "No qualified agents" && exit 1

TASK_ID=$(pilotctl --json task submit "$AGENT_ADDR" --task "Generate image" | jq -r '.task_id')

while [ "$(pilotctl --json task list | jq -r ".[] | select(.task_id == \"$TASK_ID\") | .status")" = "pending" ]; do
  sleep 2
done
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and running daemon with discoverable peers.
