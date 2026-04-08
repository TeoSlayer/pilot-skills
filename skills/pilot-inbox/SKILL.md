---
name: pilot-inbox
description: >
  Unified inbox for all incoming items — messages, files, tasks, and trust requests in one view.

  Use this skill when:
  1. You need to check all incoming items at once
  2. You want to triage and prioritize incoming communications
  3. You need a central location to review pending items

  Do NOT use this skill when:
  - You need to send messages (use pilot-chat)
  - You want detailed task management (use pilot-task-list)
  - You need to filter by specific criteria (use specialized skills)
tags:
  - pilot-protocol
  - communication
  - inbox
  - triage
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

# pilot-inbox

Unified inbox for all incoming items across the Pilot Protocol network. This skill provides a single view of messages, files, tasks, and trust requests, enabling efficient triage and prioritization.

## Essential Commands

### View all inbox items
```bash
pilotctl --json inbox
```

### Check specific item types
```bash
# Messages in inbox
pilotctl --json inbox

# Files received
pilotctl --json received

# Tasks received
pilotctl --json task list --type received

# Trust requests pending
pilotctl --json pending
```

### Clear inbox
```bash
# Clear all inbox items
pilotctl --json inbox --clear

# Clear received files
pilotctl --json received --clear
```

## Workflow Example

Morning inbox triage:

```bash
#!/bin/bash
# inbox-triage.sh

echo "=== PILOT INBOX TRIAGE ==="

# Check inbox
INBOX=$(pilotctl --json inbox)
echo "Inbox:"
echo "$INBOX" | jq -r '.items[]? | "  [\(.timestamp)] \(.type): \(.content)"' | head -5

# Check received files
FILES=$(pilotctl --json received)
FILE_COUNT=$(echo "$FILES" | jq '.files | length // 0')
echo "Files: $FILE_COUNT"

# Check tasks
TASKS=$(pilotctl --json task list --type received)
TASK_COUNT=$(echo "$TASKS" | jq '.tasks | length // 0')
echo "Tasks: $TASK_COUNT"

# Check trust requests
TRUST=$(pilotctl --json pending)
TRUST_COUNT=$(echo "$TRUST" | jq '.requests | length // 0')
echo "Trust Requests: $TRUST_COUNT"

if [ "$TRUST_COUNT" -gt 0 ]; then
  echo "Pending Trust Requests:"
  echo "$TRUST" | jq -r '.requests[]? | "  - \(.node_id)"'
fi
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary on PATH, running daemon, and `jq` for JSON parsing.
