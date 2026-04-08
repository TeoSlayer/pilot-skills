---
name: pilot-stream-data
description: >
  Real-time NDJSON data streaming over persistent Pilot Protocol connections.

  Use this skill when:
  1. You need to stream structured data in real-time between agents
  2. You want to send continuous sensor readings, logs, or metrics
  3. You need bidirectional streaming communication with backpressure

  Do NOT use this skill when:
  - You need to transfer files (use pilot-share or pilot-sync)
  - You need pub/sub broadcast (use pilot-pubsub instead)
  - You need request/response patterns (use pilot-rpc instead)
tags:
  - pilot-protocol
  - streaming
  - real-time
  - ndjson
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

# pilot-stream-data

Real-time structured data streaming using NDJSON format over Pilot Protocol's persistent connections with backpressure handling.

## Commands

**Start stream server:**
```bash
pilotctl --json listen 1002 > /tmp/pilot-stream.log &
```

**Stream NDJSON data:**
```bash
DEST="1:0001.AAAA.BBBB"
while true; do
  MSG="{\"timestamp\":$(date +%s),\"temp\":$(echo "scale=2; 20 + $RANDOM % 10" | bc),\"humidity\":50}"
  pilotctl --json send "$DEST" 1002 --data "$MSG"
  sleep 1
done
```

**Receive and process stream:**
```bash
pilotctl --json listen 1002 | while read -r line; do
  TIMESTAMP=$(echo "$line" | jq -r '.timestamp')
  VALUE=$(echo "$line" | jq -r '.value')
  echo "[$TIMESTAMP] Value: $VALUE"
done
```

**Subscribe to stream topic:**
```bash
pilotctl --json subscribe "$DEST" data-stream | while read -r line; do
  echo "Data: $(echo $line | jq -r '.value')"
done
```

## Workflow Example

```bash
#!/bin/bash
# Real-time sensor data streaming

STREAM_PORT=1002
DEST="1:0001.AAAA.BBBB"

# Producer: stream sensor data
produce_stream() {
  echo "Starting stream producer"

  # Send metadata header
  pilotctl --json send "$DEST" "$STREAM_PORT" \
    --data "{\"type\":\"stream_start\",\"schema\":\"temp_humidity_v1\"}"

  # Stream data
  counter=0
  while true; do
    timestamp=$(date +%s)
    temp=$(echo "scale=2; 20 + ($counter % 10)" | bc)
    humidity=$(echo "scale=2; 50 + ($counter % 20)" | bc)

    pilotctl --json send "$DEST" "$STREAM_PORT" \
      --data "{\"type\":\"data\",\"timestamp\":$timestamp,\"temp\":$temp,\"humidity\":$humidity,\"seq\":$counter}"

    counter=$((counter + 1))
    sleep 1
  done
}

# Consumer: receive and process
consume_stream() {
  pilotctl --json listen "$STREAM_PORT" | while read -r line; do
    type=$(echo "$line" | jq -r '.type')

    if [ "$type" = "data" ]; then
      temp=$(echo "$line" | jq -r '.temp')
      echo "Temperature: ${temp}°C"
    fi
  done
}

produce_stream
```

## Dependencies

Requires `pilot-protocol` skill, running daemon, `jq`, `bc`, and optional `gzip` for compression.
