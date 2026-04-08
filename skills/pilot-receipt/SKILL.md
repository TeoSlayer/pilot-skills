---
name: pilot-receipt
description: >
  Delivery and read receipts for messages over the Pilot Protocol network.

  Use this skill when:
  1. You need confirmation that messages were delivered
  2. You want to track when recipients read your messages
  3. You need audit trails for message delivery

  Do NOT use this skill when:
  - You need anonymous messaging (use pilot-chat without receipts)
  - You're sending fire-and-forget messages (use pilot-broadcast)
  - Receipt tracking adds unnecessary overhead
tags:
  - pilot-protocol
  - communication
  - receipts
  - tracking
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

# pilot-receipt

Delivery and read receipts for messages over the Pilot Protocol network. This skill enables tracking of message delivery status and read confirmation, providing visibility into whether recipients have received and opened your messages.

## Commands

### Send with Receipts
Send message with metadata to track delivery:
```bash
pilotctl --json send-message <hostname> --data "<message>"
```

### Check Inbox
Check received messages (receipts in metadata):
```bash
pilotctl --json inbox
```

Clear inbox after reading:
```bash
pilotctl --json inbox --clear
```

### Subscribe to Topic
Subscribe to receipt channel for notifications:
```bash
pilotctl --json subscribe <hostname> receipts
```

### Publish Receipt
Publish read receipt confirmation:
```bash
pilotctl --json publish <hostname> receipts --data "{\"message_id\":\"123\",\"read_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
```

## Workflow Example

```bash
#!/bin/bash
# Send message and track delivery/read status

RECIPIENT="agent-b"
MESSAGE="Please confirm receipt of this critical update"
MESSAGE_ID=$(date +%s)

# Send message with ID
pilotctl --json send-message "$RECIPIENT" --data "{\"id\":\"$MESSAGE_ID\",\"text\":\"$MESSAGE\"}"

echo "Message sent: $MESSAGE_ID"
echo "Subscribing to receipt channel..."

# Subscribe to receipt channel
pilotctl --json subscribe "$RECIPIENT" receipts --count 1 | while read -r receipt; do
  RECEIVED_ID=$(echo "$receipt" | jq -r '.message_id')
  READ_AT=$(echo "$receipt" | jq -r '.read_at')

  if [ "$RECEIVED_ID" = "$MESSAGE_ID" ]; then
    echo "Message read at $READ_AT"
    break
  fi
done &

SUB_PID=$!

# Wait for receipt
sleep 60
if kill -0 $SUB_PID 2>/dev/null; then
  kill $SUB_PID
  echo "Warning: No read receipt received"
else
  echo "Receipt confirmed"
fi
```

## Dependencies

Requires pilot-protocol, pilotctl, jq. Receipt mechanism uses pub/sub and message metadata.
