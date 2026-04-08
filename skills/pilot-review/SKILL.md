---
name: pilot-review
description: >
  Peer review system for task results before acceptance.

  Use this skill when:
  1. You need quality control on task results before accepting them
  2. You want independent verification from trusted reviewers
  3. You need multi-party approval for critical task outputs

  Do NOT use this skill when:
  - Task results can be verified automatically
  - Review overhead is not justified by task importance
  - You trust the executor completely
tags:
  - pilot-protocol
  - task-workflow
  - review
  - quality-control
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

# pilot-review

Peer review system for task results requiring independent verification before acceptance.

## Commands

### Request Reviewers
```bash
REVIEW_REQUEST='{"type":"review-request","task_id":"'$TASK_ID'","deadline":"'$(date -u -d '+24 hours' +%Y-%m-%dT%H:%M:%SZ)'"}'

for REVIEWER in "${REVIEWERS[@]}"; do
  pilotctl --json send-message "$REVIEWER" --data "$REVIEW_REQUEST"
done
```

### Submit Review
```bash
REVIEW='{"type":"review-submission","task_id":"'$TASK_ID'","decision":"approve","score":0.92}'
pilotctl --json send-message "$REQUESTER_ADDR" --data "$REVIEW"
```

### Finalize Review
```bash
APPROVALS=$(echo "$REVIEWS" | jq -r '[.[] | select(.data.decision == "approve")] | length')
[ $APPROVALS -ge $MIN_APPROVALS ] && echo "APPROVED" || echo "REJECTED"
```

## Workflow Example

```bash
#!/bin/bash
# Peer review system

MIN_APPROVALS=2

# Submit task
EXECUTOR=$(pilotctl --json peers --search "auditor" | jq -r '.[0].address')
TASK_ID="task-$(date +%s)"

# Wait for completion
while [ "$(pilotctl --json task list | jq -r ".[] | select(.task_id == \"$TASK_ID\") | .status")" != "completed" ]; do
  sleep 5
done

# Select reviewers
REVIEWERS=$(pilotctl --json peers --search "senior-auditor" | jq -r '.[0:3] | .[].address')

# Send review requests
for REVIEWER in $REVIEWERS; do
  pilotctl --json send-message "$REVIEWER" --data '{"type":"review-request","task_id":"'$TASK_ID'"}'
done

# Collect approvals
APPROVALS=0
while [ $APPROVALS -lt $MIN_APPROVALS ]; do
  APPROVALS=$(pilotctl --json inbox | jq -r '[.[] | select(.data.task_id == "'$TASK_ID'" and .data.decision == "approve")] | length')
  sleep 5
done

echo "APPROVED"
```

## Dependencies

Requires pilot-protocol, pilotctl, and jq.
