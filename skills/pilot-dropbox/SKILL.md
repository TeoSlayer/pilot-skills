---
name: pilot-dropbox
description: >
  Shared folder that automatically synchronizes between peers using Pilot Protocol pub/sub.

  Use this skill when:
  1. You need a persistent shared folder that stays in sync across agents
  2. You want automatic file synchronization without manual intervention
  3. You need multi-peer folder sharing with eventual consistency

  Do NOT use this skill when:
  - You only need one-time file transfer (use pilot-share instead)
  - You need strict consistency guarantees (use pilot-sync with locks)
  - You need real-time streaming (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - file-transfer
  - shared-folder
  - pub-sub
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

# pilot-dropbox

Shared folder implementation using Pilot Protocol pub/sub and file transfer. Provides Dropbox-like functionality with eventual consistency.

## Essential Commands

### Create and join shared folder
```bash
DROPBOX_DIR="$HOME/pilot-dropbox"
PEER="agent-b"
TOPIC="team-shared"
mkdir -p "$DROPBOX_DIR"

pilotctl --json subscribe "$PEER" "$TOPIC"
```

### Publish file to folder
```bash
cp "$FILE" "$DROPBOX_DIR/"
FILENAME=$(basename "$FILE")
HASH=$(md5sum "$DROPBOX_DIR/$FILENAME" | cut -d' ' -f1)

pilotctl --json publish "$PEER" "$TOPIC" \
  --data "{\"type\":\"file_added\",\"filename\":\"$FILENAME\",\"hash\":\"$HASH\"}"
```

### Remove file from folder
```bash
rm "$DROPBOX_DIR/$FILENAME"
pilotctl --json publish "$PEER" "$TOPIC" \
  --data "{\"type\":\"file_removed\",\"filename\":\"$FILENAME\"}"
```

### Watch folder for changes
```bash
fswatch -0 "$DROPBOX_DIR" | while read -d "" changed_file; do
  [ -f "$changed_file" ] || continue
  FILENAME=$(basename "$changed_file")
  HASH=$(md5sum "$changed_file" | cut -d' ' -f1)
  pilotctl --json publish "$PEER" "$TOPIC" \
    --data "{\"type\":\"file_changed\",\"filename\":\"$FILENAME\",\"hash\":\"$HASH\"}"
done &
```

## Workflow Example

Shared folder daemon:

```bash
#!/bin/bash
DROPBOX_DIR="$HOME/pilot-dropbox"
PEER="${1:-agent-b}"
TOPIC="team-shared"

mkdir -p "$DROPBOX_DIR"

# Listen for events
pilotctl --json subscribe "$PEER" "$TOPIC" | while read -r event; do
  TYPE=$(echo "$event" | jq -r '.type')
  FROM=$(echo "$event" | jq -r '.from')

  case "$TYPE" in
    file_added)
      FILENAME=$(echo "$event" | jq -r '.filename')
      HASH=$(echo "$event" | jq -r '.hash')

      if [ -f "$DROPBOX_DIR/$FILENAME" ]; then
        LOCAL_HASH=$(md5sum "$DROPBOX_DIR/$FILENAME" | cut -d' ' -f1)
        [ "$LOCAL_HASH" = "$HASH" ] && continue
      fi

      echo "Pulling: $FILENAME from $FROM"
      pilotctl --json send-message "$FROM" \
        --data "{\"type\":\"dropbox_pull\",\"filename\":\"$FILENAME\"}"
      ;;

    file_removed)
      FILENAME=$(echo "$event" | jq -r '.filename')
      rm -f "$DROPBOX_DIR/$FILENAME"
      ;;

    dropbox_pull)
      FILENAME=$(echo "$event" | jq -r '.filename')
      pilotctl --json send-file "$FROM" "$DROPBOX_DIR/$FILENAME"
      ;;
  esac
done
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl`, `jq`, `fswatch` (macOS) or `inotifywait` (Linux), and file utilities.
