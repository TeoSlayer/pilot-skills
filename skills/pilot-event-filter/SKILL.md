---
name: pilot-event-filter
description: >
  Filter and transform events before delivery using pattern matching and jq transforms.

  Use this skill when:
  1. You need to filter events by content, not just topic wildcards
  2. You need to transform event payloads before processing
  3. You need to route events conditionally based on content
  4. You need to reduce event noise by selective forwarding

  Do NOT use this skill when:
  - Topic wildcards alone are sufficient (use pilot-event-bus instead)
  - You need all events without filtering (subscribe directly)
  - You need persistent storage (use pilot-event-log instead)
tags:
  - pilot-protocol
  - pub-sub
  - filtering
  - transformation
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
  Requires jq for JSON filtering and transformation.
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - jq
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Pilot Event Filter

Filter and transform Pilot Protocol event streams using jq-based pattern matching.

## Commands

### Subscribe with filtering
```bash
pilotctl --json subscribe <source-hostname> <topic> --timeout 60 | \
  jq -c '.data.events[] | select(<filter-expression>)'
```

### Transform and republish
```bash
pilotctl --json subscribe <source> <topic> --timeout 60 | \
  jq -c '.data.events[] | <transform-expression>' | \
  while IFS= read -r event; do
    pilotctl --json publish <destination> "<new-topic>" --data "$event"
  done
```

## Workflow Example

Filter critical alerts and forward to on-call agent:

```bash
#!/bin/bash
SOURCE_AGENT="monitoring-hub"
ONCALL_AGENT="oncall-agent"

pilotctl --json subscribe "$SOURCE_AGENT" "alerts.*" --timeout 600 | \
  jq -c '.data.events[]' | \
  while IFS= read -r event; do
    severity=$(echo "$event" | jq -r '.data | fromjson | .severity // "unknown"')

    if [ "$severity" = "critical" ]; then
      pilotctl --json publish "$ONCALL_AGENT" "oncall.critical" --data "$event"
    fi
  done
```

## Dependencies

Requires pilot-protocol skill, jq, and a running daemon.
