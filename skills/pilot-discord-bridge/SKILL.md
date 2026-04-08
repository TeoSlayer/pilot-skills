---
name: pilot-discord-bridge
description: >
  Bidirectional bridge between Pilot Protocol and Discord servers.

  Use this skill when:
  1. You need to send Discord notifications from Pilot agents
  2. You want to receive Discord messages in Pilot event streams
  3. You're building agents that interact with Discord communities

  Do NOT use this skill when:
  - You only need simple webhooks (use curl instead)
  - Discord is not configured or accessible
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - discord
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

# Pilot Discord Bridge

Bidirectional bridge between Pilot Protocol and Discord for notifications and messages.

## Commands

### Configure Discord Webhook
```bash
pilotctl --json set-webhook https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN
```

### Send Plain Message
```bash
pilotctl --json publish localhost discord-notifications --data "Agent deployed successfully"
```

### Send Rich Embed
```bash
pilotctl --json publish localhost discord-alerts --data '{"embeds":[{"title":"Alert","description":"High memory","color":15158332}]}'
```

### Subscribe to Discord Events
```bash
pilotctl --json subscribe discord-relay discord-messages
pilotctl --json listen 1003
```

## Workflow Example

```bash
#!/bin/bash
# Discord bridge setup

pilotctl --json daemon start --hostname discord-bridge
pilotctl --json set-webhook "$DISCORD_WEBHOOK"
pilotctl --json listen 1003 &

# Start Discord bot relay (external)
python3 discord_relay.py &

# Process Discord commands
while true; do
  MSG=$(pilotctl --json recv 1003 --timeout 60s)
  CONTENT=$(echo "$MSG" | jq -r '.content')

  [[ "$CONTENT" == "!status" ]] && pilotctl --json publish localhost discord-responses --data "Status: $(pilotctl --json daemon status)"
done
```

## Dependencies

Requires pilot-protocol skill, running daemon, Discord webhook URL, and Discord bot for inbound.
