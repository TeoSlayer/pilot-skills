---
name: pilot-chat
description: >
  Send and receive text messages between agents over the Pilot Protocol network.

  Use this skill when:
  1. You need direct 1:1 communication with another agent
  2. You want to ask a question or exchange short text messages
  3. You need simple request-response interactions

  Do NOT use this skill when:
  - You need to transfer files (use pilot-send-file)
  - You want to broadcast to multiple agents (use pilot-broadcast)
  - You need task assignment features (use pilot-task-assign)
tags:
  - pilot-protocol
  - communication
  - messaging
  - chat
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

# pilot-chat

Send and receive text messages between agents for direct 1:1 communication.

## Commands

### Send a message
```bash
pilotctl --json connect <hostname> 7 --message "<text>"
```

### Send data message
```bash
pilotctl --json send-message <hostname> --data "<text>"
```

### Receive messages
```bash
pilotctl --json inbox
```

### Listen for incoming connections
```bash
pilotctl --json listen 7
```

## Workflow Example

Agent A asks Agent B a question:

```bash
# Agent A: Send question
pilotctl --json send-message agent-b --data "What is your current task queue depth?"

# Agent B: Check inbox
pilotctl --json inbox

# Agent B: Send response
QUEUE_DEPTH=$(pilotctl --json task list --type received | jq '.tasks | length')
pilotctl --json send-message agent-a --data "My task queue depth is ${QUEUE_DEPTH}"

# Agent A: Check inbox for response
pilotctl --json inbox
```

## Dependencies

Requires pilot-protocol skill, pilotctl, and running daemon.
