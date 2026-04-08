---
name: pilot-event-replay
description: >
  Record and replay event streams for debugging, testing, and audit purposes.

  Use this skill when:
  1. You need to capture event streams for later analysis
  2. You need to replay events to test downstream consumers
  3. You need to debug event-driven workflows
  4. You need to audit event history with timestamps

  Do NOT use this skill when:
  - You need real-time event forwarding (use pilot-event-bus instead)
  - You need long-term storage with rotation (use pilot-event-log instead)
  - You need filtering before recording (use pilot-event-filter first)
tags:
  - pilot-protocol
  - pub-sub
  - debugging
  - testing
  - replay
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
  Requires jq for JSON processing.
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

# Pilot Event Replay

Record event streams to NDJSON files and replay them for debugging and testing.

## Commands

### Record events to file
```bash
pilotctl --json subscribe <source-hostname> <topic> --timeout <seconds> | \
  jq -c '.data.events[]' >> <recording-file.ndjson>
```

### Replay events from file
```bash
cat <recording-file.ndjson> | jq -c '.' | while IFS= read -r event; do
  topic=$(echo "$event" | jq -r '.topic')
  data=$(echo "$event" | jq -r '.data')

  pilotctl --json publish <target-hostname> "$topic" --data "$data"
  sleep <delay-seconds>
done
```

## Workflow Example

Record debug session:

```bash
#!/bin/bash
SOURCE="buggy-worker"
DURATION=300
RECORDING="/tmp/debug-session-$(date +%Y%m%d-%H%M%S).ndjson"

pilotctl --json subscribe "$SOURCE" "*" --timeout "$DURATION" | \
  jq -c '.data.events[]' >> "$RECORDING"

event_count=$(wc -l < "$RECORDING")
echo "Recorded $event_count events"
```

Replay to test agent:

```bash
#!/bin/bash
RECORDING="$1"
TEST_TARGET="test-agent"

jq -c '.' "$RECORDING" | while IFS= read -r event; do
  topic=$(echo "$event" | jq -r '.topic')
  data=$(echo "$event" | jq -r '.data')

  pilotctl --json publish "$TEST_TARGET" "$topic" --data "$data"
  sleep 0.5
done
```

## Dependencies

Requires pilot-protocol skill, jq, and a running daemon.
