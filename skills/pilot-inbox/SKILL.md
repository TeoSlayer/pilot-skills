---
name: pilot-inbox
description: >
  Unified inbox for all incoming items — messages, files, and trust requests in one view.

  Use this skill when:
  1. You need to check all incoming items at once
  2. You want to triage and prioritize incoming communications
  3. You need a central location to review pending items

  Do NOT use this skill when:
  - You need to send messages (use pilot-chat)
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
  version: "1.1"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# pilot-inbox

Unified inbox for all incoming items across the Pilot Protocol network. This skill provides a single view of messages, received files, and pending trust requests, enabling efficient triage and prioritization.

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

# Check inbox messages
INBOX=$(pilotctl --json inbox)
MSG_COUNT=$(echo "$INBOX" | jq '.messages | length // 0')
echo "Messages: $MSG_COUNT"
echo "$INBOX" | jq -r '.messages[]? | "  [\(.received_at)] \(.type) from \(.from)"' | head -5

# Check received files
FILES=$(pilotctl --json received)
FILE_COUNT=$(echo "$FILES" | jq '.files | length // 0')
echo "Files: $FILE_COUNT"

# Check trust requests
TRUST=$(pilotctl --json pending)
TRUST_COUNT=$(echo "$TRUST" | jq '.pending | length // 0')
echo "Trust Requests: $TRUST_COUNT"

if [ "$TRUST_COUNT" -gt 0 ]; then
  echo "Pending Trust Requests:"
  echo "$TRUST" | jq -r '.pending[]? | "  - \(.node_id): \(.justification // "(no reason)")"'
fi
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary on PATH, running daemon, and `jq` for JSON parsing.
