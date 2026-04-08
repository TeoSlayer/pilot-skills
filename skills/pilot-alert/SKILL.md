---
name: pilot-alert
description: >
  Configurable alerting on event patterns with webhook and message delivery.

  Use this skill when:
  1. You need to trigger alerts based on event patterns or thresholds
  2. You need to notify external services (Slack, Discord, PagerDuty) of events
  3. You need to escalate critical events to on-call agents
  4. You need to aggregate and deduplicate alerts

  Do NOT use this skill when:
  - You need simple event forwarding (use pilot-event-bus instead)
  - You need persistent logging (use pilot-event-log instead)
  - You need all events without filtering (subscribe directly)
tags:
  - pilot-protocol
  - pub-sub
  - alerting
  - monitoring
  - webhooks
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
  Requires jq and curl for webhook delivery.
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - jq
        - curl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Pilot Alert

Subscribe to events and trigger configurable alerts based on patterns, thresholds, or conditions. Supports webhook delivery and direct agent messaging.

## Essential Commands

### Subscribe to events
```bash
pilotctl --json subscribe <source-hostname> <topic> [--timeout <seconds>]
```

### Send alert message
```bash
pilotctl --json send-message <target-hostname> --data <alert-payload>
```

### Webhook delivery
```bash
curl -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "$payload"
```

## Workflow: Critical Error Alerting

```bash
#!/bin/bash
SOURCE="production-app"
TOPIC="alerts.error.*"
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK"

pilotctl --json subscribe "$SOURCE" "$TOPIC" --timeout 600 | \
  jq -c '.data.events[]' | \
  while IFS= read -r event; do
    severity=$(echo "$event" | jq -r '.data | fromjson | .severity // "unknown"')

    if [ "$severity" = "critical" ]; then
      message=$(echo "$event" | jq -r '.data | fromjson | .message')

      # Alert via Slack
      slack_payload=$(jq -n --arg msg "$message" '{text: "CRITICAL", attachments: [{color: "danger", text: $msg}]}')
      curl -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "$slack_payload" --silent

      # Alert via Pilot
      pilotctl --json send-message oncall-agent --data "{\"type\":\"critical_alert\",\"message\":\"$message\"}"
    fi
  done
```

## Workflow: Threshold Alerting

```bash
#!/bin/bash
THRESHOLD=80
CONSECUTIVE_LIMIT=3
consecutive_count=0

pilotctl --json subscribe worker-node metrics.cpu --timeout 300 | \
  jq -c '.data.events[]' | \
  while IFS= read -r event; do
    usage=$(echo "$event" | jq -r '.data | fromjson | .usage // 0')

    if [ "$(echo "$usage > $THRESHOLD" | bc)" = "1" ]; then
      consecutive_count=$((consecutive_count + 1))

      if [ "$consecutive_count" -ge "$CONSECUTIVE_LIMIT" ]; then
        echo "ALERT: CPU sustained above $THRESHOLD%"
        # Send alert...
        consecutive_count=0
      fi
    else
      consecutive_count=0
    fi
  done
```

## Workflow: Alert Deduplication

```bash
#!/bin/bash
DEDUP_WINDOW=300
ALERT_FILE="/tmp/alert-cache.txt"

pilotctl --json subscribe app-cluster "alerts.*" --timeout 600 | \
  jq -c '.data.events[]' | \
  while IFS= read -r event; do
    alert_key="$(echo "$event" | jq -r '.topic'):$(echo "$event" | jq -r '.data' | md5sum | cut -d' ' -f1)"
    now=$(date +%s)

    last_sent=$(grep "^$alert_key " "$ALERT_FILE" 2>/dev/null | cut -d' ' -f2)

    if [ -n "$last_sent" ] && [ $((now - last_sent)) -lt $DEDUP_WINDOW ]; then
      echo "Suppressed duplicate"
      continue
    fi

    # Send alert
    pilotctl --json send-message oncall-agent --data "$(echo "$event" | jq -r '.data')"

    # Update cache
    grep -v "^$alert_key " "$ALERT_FILE" > "${ALERT_FILE}.tmp" 2>/dev/null || true
    echo "$alert_key $now" >> "${ALERT_FILE}.tmp"
    mv "${ALERT_FILE}.tmp" "$ALERT_FILE"
  done
```

## Dependencies

Requires `pilot-protocol` skill, `jq`, `curl`, `pilotctl` binary, running daemon, and trust with source agents.
