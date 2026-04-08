---
name: pilot-priority-queue
description: >
  Priority-based message delivery with urgency levels over the Pilot Protocol network.

  Use this skill when:
  1. You need urgent message handling with priority levels
  2. You want to implement SLA-based message delivery
  3. You need priority triage for incoming messages

  Do NOT use this skill when:
  - All messages have equal priority (use pilot-chat)
  - You need file transfer (use pilot-send-file)
  - You need real-time streaming (use pilot-connect)
tags:
  - pilot-protocol
  - communication
  - priority
  - queue
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

# pilot-priority-queue

Priority-based message delivery with urgency levels over the Pilot Protocol network. This skill enables structured message prioritization, ensuring urgent communications are processed first while maintaining ordered delivery for messages of equal priority.

## Commands

### Send messages with priority prefix

```bash
# Send critical message with [CRITICAL] prefix
pilotctl --json send-message <hostname> --data "[CRITICAL] System alert"

# Send high priority with [HIGH] prefix
pilotctl --json send-message <hostname> --data "[HIGH] Urgent task"

# Send normal message
pilotctl --json send-message <hostname> --data "Regular update"

# Send low priority with [LOW] prefix
pilotctl --json send-message <hostname> --data "[LOW] FYI: Log summary"
```

### Receive and filter by priority

```bash
# View all inbox
pilotctl --json inbox

# Filter critical messages using jq
pilotctl --json inbox | jq '.items[]? | select(.content | startswith("[CRITICAL]"))'

# Filter high priority
pilotctl --json inbox | jq '.items[]? | select(.content | startswith("[HIGH]"))'
```

### Manual queue management

```bash
# Clear inbox after processing
pilotctl --json inbox --clear
```

## Workflow Example

Process messages by priority with automatic triage:

```bash
#!/bin/bash
# Process priority inbox using prefix tags

INBOX=$(pilotctl --json inbox)

# Extract and count by priority prefix
CRITICAL_COUNT=$(echo "$INBOX" | jq '[.items[]? | select(.content | startswith("[CRITICAL]"))] | length')
HIGH_COUNT=$(echo "$INBOX" | jq '[.items[]? | select(.content | startswith("[HIGH]"))] | length')
NORMAL_COUNT=$(echo "$INBOX" | jq '[.items[]? | select(.content | (startswith("[CRITICAL]") or startswith("[HIGH]") or startswith("[LOW]")) | not)] | length')
LOW_COUNT=$(echo "$INBOX" | jq '[.items[]? | select(.content | startswith("[LOW]"))] | length')

echo "Critical: $CRITICAL_COUNT, High: $HIGH_COUNT, Normal: $NORMAL_COUNT, Low: $LOW_COUNT"

# Process critical first
if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "CRITICAL MESSAGES:"
  echo "$INBOX" | jq -r '.items[]? | select(.content | startswith("[CRITICAL]")) |
    "[\(.timestamp // "N/A")] \(.content)"'
fi

# Process high priority
if [ "$HIGH_COUNT" -gt 0 ]; then
  echo "HIGH PRIORITY:"
  echo "$INBOX" | jq -r '.items[]? | select(.content | startswith("[HIGH]")) |
    "[\(.timestamp // "N/A")] \(.content)"'
fi
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, and running daemon.
