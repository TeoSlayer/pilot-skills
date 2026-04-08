---
name: pilot-relay
description: >
  Store-and-forward messaging for offline peers over the Pilot Protocol network.

  Use this skill when:
  1. You need to send messages to agents that may be offline
  2. You want guaranteed eventual delivery
  3. You need asynchronous communication patterns

  Do NOT use this skill when:
  - You need real-time chat (use pilot-chat with online peers)
  - You need streaming data (use pilot-connect)
  - You need immediate confirmation (use pilot-chat with receipts)
tags:
  - pilot-protocol
  - communication
  - relay
  - async
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

# pilot-relay

Store-and-forward messaging for offline peers. Enables guaranteed message delivery to agents that may be temporarily offline, with automatic delivery when they come back online.

## Essential Commands

### Send message (auto-relayed if peer offline)
```bash
pilotctl --json send-message <hostname> --data "<message>"
```

### Check daemon status
```bash
pilotctl --json daemon status
```

### Retrieve messages from inbox
```bash
pilotctl --json inbox
```

### Clear inbox after processing
```bash
pilotctl --json inbox --clear
```

## Workflow Example

Agent A sends to Agent B (message auto-relayed if B is offline):

```bash
#!/bin/bash
# Agent A (sender)

# Try to find Agent B
pilotctl --json find agent-b

# Send message (auto-queued for relay if offline)
pilotctl --json send-message agent-b --data "Important: Database migration tonight"

# Check daemon status
pilotctl --json daemon status
```

Agent B comes online and retrieves messages:

```bash
#!/bin/bash
# Agent B (receiver)

# Start daemon (auto-retrieves relayed messages)
pilotctl --json daemon start

# Check inbox for messages
INBOX=$(pilotctl --json inbox)
echo "$INBOX" | jq -r '.items[]? | "[\(.timestamp)] \(.content)"'

# Send acknowledgment reply
pilotctl --json send-message agent-a --data "Acknowledged: Will monitor migration"

# Clear inbox
pilotctl --json inbox --clear
```

## Relay Behavior

### Automatic queuing
Messages are automatically queued when:
- Recipient peer is offline
- Direct connection fails after retries
- Peer is behind symmetric NAT without relay support

### Delivery guarantees
- At-least-once delivery
- Ordered per-sender
- 7-day retention
- Automatic retry

### Relay nodes
- Registered rendezvous servers act as relay points
- Messages are encrypted end-to-end (relay cannot read content)
- Relay nodes store messages temporarily until delivery

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, registry connection, and trust relationship between sender/recipient.
