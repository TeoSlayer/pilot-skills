---
name: pilot-a2a-bridge
description: >
  Bridge A2A (Agent-to-Agent) protocol messages over Pilot tunnels.

  Use this skill when:
  1. You need to connect A2A agents across different networks
  2. You want to route A2A messages through Pilot's overlay network
  3. You're building multi-agent systems that need reliable messaging

  Do NOT use this skill when:
  - Agents are on the same local network (use direct A2A instead)
  - You need raw TCP/UDP access (use pilot-protocol directly)
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - a2a
  - bridge
  - agent-messaging
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

# Pilot A2A Bridge

Bridge Agent-to-Agent protocol messages over Pilot tunnels with NAT traversal and encryption.

## Commands

### Start A2A Bridge
```bash
pilotctl --json daemon start --hostname a2a-agent-1
pilotctl --json listen 5000
```

### Send A2A Message
```bash
pilotctl --json send-message remote-agent --data '{"type":"task","action":"analyze","payload":"data"}'
```

### Subscribe to A2A Events
```bash
pilotctl --json subscribe remote-agent a2a-events
```

### Receive A2A Messages
```bash
pilotctl --json recv 5000
```

## Workflow Example

```bash
#!/bin/bash
# Agent A: A2A bridge listener

pilotctl --json daemon start --hostname agent-a
pilotctl --json listen 5000

while true; do
  MSG=$(pilotctl --json recv 5000 --timeout 30s)
  TYPE=$(echo "$MSG" | jq -r '.type')
  SENDER=$(echo "$MSG" | jq -r '.sender')

  case "$TYPE" in
    task)
      RESULT=$(process_task "$(echo "$MSG" | jq -r '.payload')")
      pilotctl --json send-message "$SENDER" --data "{\"type\":\"result\",\"data\":\"$RESULT\"}"
      ;;
  esac
done
```

## Message Format

```json
{
  "type": "task|result|event|status",
  "action": "analyze|process|compute",
  "payload": "arbitrary data"
}
```

## Dependencies

Requires pilot-protocol skill with running daemon and A2A-compatible agents.
