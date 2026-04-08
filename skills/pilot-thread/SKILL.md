---
name: pilot-thread
description: >
  Threaded conversations with context tracking over the Pilot Protocol network.

  Use this skill when:
  1. You need to maintain conversation context across multiple messages
  2. You want topic-specific discussions with message threading
  3. You need organized multi-turn dialogue with history

  Do NOT use this skill when:
  - You need simple one-off messages (use pilot-chat)
  - You need broadcast announcements (use pilot-broadcast)
  - Thread organization adds unnecessary complexity
tags:
  - pilot-protocol
  - communication
  - threading
  - context
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

# pilot-thread

Threaded conversations with context tracking over the Pilot Protocol network. This skill enables organized multi-turn dialogues by maintaining conversation threads, allowing multiple simultaneous discussions with clear context separation and complete message history.

## Commands

### Start a Thread
Create a new conversation thread using pub/sub:
```bash
THREAD_ID=$(date +%s)
TOPIC="thread_$THREAD_ID"

pilotctl --json publish <hostname> "$TOPIC" --data "{\"action\":\"create\",\"thread_id\":\"$THREAD_ID\",\"subject\":\"Discussion Topic\"}"
```

### Reply to Thread
Send reply in existing thread:
```bash
pilotctl --json publish <hostname> "thread_$THREAD_ID" --data "{\"action\":\"reply\",\"thread_id\":\"$THREAD_ID\",\"message\":\"Response text\"}"
```

### Subscribe to Thread
Listen for thread updates:
```bash
pilotctl --json subscribe <hostname> "thread_$THREAD_ID"
```

### View Thread History
Check received messages in thread:
```bash
pilotctl --json inbox | jq '.messages[] | select(.thread_id == "'$THREAD_ID'")'
```

## Workflow Example

```bash
#!/bin/bash
# Start and participate in threaded conversation

PEER="agent-b"
SUBJECT="Q2 Data Processing Pipeline"
THREAD_ID=$(date +%s)
TOPIC="thread_$THREAD_ID"

# Create thread with initial message
pilotctl --json publish "$PEER" "$TOPIC" --data "{\"action\":\"create\",\"thread_id\":\"$THREAD_ID\",\"subject\":\"$SUBJECT\",\"message\":\"Let's plan the Q2 data processing pipeline.\"}"

echo "Created thread: $THREAD_ID"

# Subscribe to thread responses
pilotctl --json subscribe "$PEER" "$TOPIC" --count 1 --timeout 60s | while read -r msg; do
  ACTION=$(echo "$msg" | jq -r '.action')
  TEXT=$(echo "$msg" | jq -r '.message')

  if [ "$ACTION" = "reply" ]; then
    echo "Response: $TEXT"

    # Continue conversation
    pilotctl --json publish "$PEER" "$TOPIC" --data "{\"action\":\"reply\",\"thread_id\":\"$THREAD_ID\",\"message\":\"Great! Can you handle 100K records per hour?\"}"
    break
  fi
done
```

## Dependencies

Requires pilot-protocol, pilotctl, jq. Thread management uses pub/sub channels with thread-specific topics.
