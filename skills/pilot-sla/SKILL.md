---
name: pilot-sla
description: >
  Service-level agreement enforcement with automatic penalties.

  Use this skill when:
  1. You need guaranteed performance levels for critical tasks
  2. You want automatic penalty enforcement for SLA violations
  3. You need uptime, latency, or quality guarantees from agents

  Do NOT use this skill when:
  - Tasks don't have strict performance requirements
  - Best-effort execution is acceptable
  - You don't need automated compliance monitoring
tags:
  - pilot-protocol
  - task-workflow
  - sla
  - compliance
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

# pilot-sla

Service-level agreement enforcement with automatic penalty assessment.

## Commands

### Define SLA Contract
```bash
cat > sla-contract.json <<EOF
{
  "sla_id": "sla-$(date +%s)",
  "metrics": {"max_response_time_ms": 2000, "min_success_rate": 0.95},
  "penalties": {"response_time_violation": 5, "failed_task": 10}
}
EOF
```

### Monitor Compliance
```bash
TASK_SUBMIT_TIME=$(date +%s%3N)
TASK_COMPLETE_TIME=$(date +%s%3N)
COMPLETION_TIME=$((TASK_COMPLETE_TIME - TASK_SUBMIT_TIME))

SLA_MAX_TIME=$(jq -r '.metrics.max_response_time_ms' sla-contract.json)
[ $COMPLETION_TIME -gt $SLA_MAX_TIME ] && echo "SLA violation"
```

### Calculate Success Rate
```bash
TOTAL=$(pilotctl --json task list | jq -r "[.[] | select(.target == \"$AGENT\")] | length")
SUCCESSFUL=$(pilotctl --json task list | jq -r "[.[] | select(.target == \"$AGENT\") | select(.status == \"completed\")] | length")

SUCCESS_RATE=$(echo "scale=4; $SUCCESSFUL / $TOTAL" | bc)
```

## Workflow Example

```bash
#!/bin/bash
# SLA enforcement

SLA_ID="sla-$(date +%s)"
SLA_MAX=3000

for i in {1..10}; do
  SUBMIT_TIME=$(date +%s%3N)
  TASK_ID=$(pilotctl --json task submit "$AGENT" --task "api-call: task_id=$i" | jq -r '.task_id')

  while [ "$(pilotctl --json task list | jq -r ".[] | select(.task_id == \"$TASK_ID\") | .status")" = "pending" ]; do
    sleep 0.5
  done

  RESPONSE_TIME=$(($(date +%s%3N) - SUBMIT_TIME))
  [ $RESPONSE_TIME -gt $SLA_MAX ] && echo "SLA violation: task $i took ${RESPONSE_TIME}ms"
done
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and bc.
