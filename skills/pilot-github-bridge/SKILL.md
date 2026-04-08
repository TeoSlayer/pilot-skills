---
name: pilot-github-bridge
description: >
  Bridge GitHub webhook events as Pilot Protocol events.

  Use this skill when:
  1. You need to receive GitHub events in Pilot agents
  2. You want to trigger agent actions on repository events
  3. You're building CI/CD workflows with Pilot agents

  Do NOT use this skill when:
  - You need direct GitHub API access (use gh CLI instead)
  - GitHub webhooks are not configured
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - github
  - bridge
  - ci-cd
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

# pilot-github-bridge

Bridge GitHub webhook events into Pilot Protocol, enabling agents to react to repository events.

## Commands

### Configure Webhook Receiver
```bash
pilotctl --json set-webhook https://your-relay.example.com/github
pilotctl --json listen 1005
```

### Subscribe to Events
```bash
pilotctl --json subscribe github-relay github-events
```

### Check Received Events
```bash
pilotctl --json inbox
pilotctl --json recv 1005
```

## Workflow Example

```bash
#!/bin/bash
# GitHub webhook relay

pilotctl --json daemon start --hostname github-relay --public
pilotctl --json listen 1005 &

# Start HTTP relay (external Python server)
python3 github_relay_server.py &

# Process events
pilotctl --json subscribe localhost github-events

while true; do
  EVENT=$(pilotctl --json recv 1005 --timeout 120s)
  REPO=$(echo "$EVENT" | jq -r '.repository.full_name')
  EVENT_TYPE=$(echo "$EVENT" | jq -r '.event')

  case "$EVENT_TYPE" in
    push)
      BRANCH=$(echo "$EVENT" | jq -r '.ref' | sed 's/refs\/heads\///')
      [ "$BRANCH" = "main" ] && pilotctl --json send-message ci-builder --data "{\"action\":\"build\",\"repo\":\"$REPO\"}"
      ;;
    pull_request)
      ACTION=$(echo "$EVENT" | jq -r '.action')
      [ "$ACTION" = "opened" ] && pilotctl --json send-message code-reviewer --data "{\"repo\":\"$REPO\",\"pr\":$(echo "$EVENT" | jq -r '.number')}"
      ;;
  esac
done
```

## Dependencies

Requires pilot-protocol skill, running daemon, gh CLI, GitHub webhook, and HTTP relay server.
