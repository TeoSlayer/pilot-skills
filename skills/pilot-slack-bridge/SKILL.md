---
name: pilot-slack-bridge
description: >
  Bidirectional bridge between Pilot Protocol and Slack channels.

  Use this skill when:
  1. You need to send Slack notifications from Pilot agents
  2. You want to receive Slack messages in Pilot event streams
  3. You're building agents that interact with Slack workspaces

  Do NOT use this skill when:
  - You only need simple webhooks (use curl instead)
  - Slack is not configured or accessible
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - slack
  - bridge
  - notifications
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

# Pilot Slack Bridge

Bidirectional bridge between Pilot Protocol and Slack for notifications and messages.

## Commands

### Configure Slack Webhook
```bash
pilotctl --json set-webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Send Plain Message
```bash
pilotctl --json publish localhost slack-notifications --data "Agent started successfully"
```

### Send Structured Message
```bash
pilotctl --json publish localhost slack-alerts --data '{"text":"Error","attachments":[{"color":"danger","title":"Alert"}]}'
```

### Subscribe to Slack Events
```bash
pilotctl --json subscribe relay-agent slack-events
pilotctl --json listen 1002
```

## Workflow Example

```bash
#!/bin/bash
# Slack bridge setup

pilotctl --json daemon start --hostname slack-relay --public
pilotctl --json set-webhook "$SLACK_WEBHOOK"
pilotctl --json listen 1002 &

# Start HTTP relay (external)
python3 slack_relay.py &

# Process Slack commands
while true; do
  EVENT=$(pilotctl --json recv 1002 --timeout 60s)
  TEXT=$(echo "$EVENT" | jq -r '.event.text')

  case "$TEXT" in
    "status")
      pilotctl --json publish localhost slack-responses --data "Status: $(pilotctl --json daemon status)"
      ;;
    "list agents")
      pilotctl --json publish localhost slack-responses --data "Agents: $(pilotctl --json peers)"
      ;;
  esac
done
```

## Dependencies

Requires pilot-protocol skill, running daemon, Slack webhook URL, and HTTP relay service for inbound.
