---
name: pilot-webhook-bridge
description: >
  Forward Pilot Protocol events to HTTP webhooks for Slack, Discord, PagerDuty, and custom integrations.

  Use this skill when:
  1. You need to forward Pilot events to external services (Slack, Discord, Teams)
  2. You need to integrate with monitoring/alerting platforms (PagerDuty, Datadog)
  3. You need to trigger external workflows via webhooks
  4. You need bidirectional sync between Pilot and external systems

  Do NOT use this skill when:
  - You need agent-to-agent messaging (use pilot-protocol directly)
  - You need persistent storage (use pilot-event-log instead)
  - You need complex transformations (use pilot-event-filter first)
tags:
  - pilot-protocol
  - pub-sub
  - webhooks
  - integration
  - slack
  - discord
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
  Requires curl for HTTP requests and jq for JSON processing.
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - curl
        - jq
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# pilot-webhook-bridge

Forward Pilot Protocol events (port 1002) to HTTP webhooks for integration with Slack, Discord, Microsoft Teams, PagerDuty, and custom HTTP endpoints.

## Commands

### Configure global webhook

```bash
pilotctl --json set-webhook <webhook-url>
```

All events on port 1002 are forwarded as HTTP POST with JSON payload.

### Clear webhook

```bash
pilotctl --json clear-webhook
```

### Subscribe and forward (selective)

```bash
pilotctl --json subscribe <source-hostname> <topic> --timeout <seconds> | \
  jq -c '.data.events[]' | \
  while IFS= read -r event; do
    curl -X POST <webhook-url> -H "Content-Type: application/json" -d "$event"
  done
```

## Workflow: Slack Integration

```bash
SOURCE="production-app"
TOPIC="alerts.*"
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
TIMEOUT=600

pilotctl --json subscribe "$SOURCE" "$TOPIC" --timeout "$TIMEOUT" | \
  jq -c '.data.events[]' | \
  while IFS= read -r event; do
    topic=$(echo "$event" | jq -r '.topic')
    message=$(echo "$event" | jq -r '.data.message // .')
    severity=$(echo "$event" | jq -r '.data.severity // "info"')

    # Map severity to color
    case "$severity" in
      critical|error) color="danger" ;;
      warning) color="warning" ;;
      *) color="good" ;;
    esac

    # Build Slack payload
    slack_payload=$(jq -n \
      --arg text "Pilot Event: $topic" \
      --arg msg "$message" \
      --arg color "$color" \
      '{
        text: $text,
        attachments: [{
          color: $color,
          fields: [{title: "Message", value: $msg, short: false}]
        }]
      }')

    curl -X POST "$SLACK_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "$slack_payload" \
      --silent --show-error
  done
```

## Workflow: Discord Integration

```bash
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR/WEBHOOK"

pilotctl --json subscribe "$SOURCE" "$TOPIC" --timeout 300 | \
  jq -c '.data.events[]' | \
  while IFS= read -r event; do
    topic=$(echo "$event" | jq -r '.topic')
    value=$(echo "$event" | jq -r '.data.value // .data')

    discord_payload=$(jq -n \
      --arg title "Metric: $topic" \
      --arg value "$value" \
      '{
        embeds: [{
          title: $title,
          description: "Value: " + $value,
          color: 3447003
        }]
      }')

    curl -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "$discord_payload" \
      --silent --show-error
  done
```

## Dependencies

Requires pilot-protocol skill, curl, jq, running daemon, and trust relationships with source agents.
