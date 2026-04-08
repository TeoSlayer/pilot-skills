---
name: pilot-sync
description: >
  Bidirectional file synchronization between agents over the Pilot Protocol network.

  Use this skill when:
  1. You need to keep directories synchronized between two agents
  2. You want to replicate files across multiple nodes with conflict detection
  3. You need to maintain consistent file state across distributed agents

  Do NOT use this skill when:
  - You only need one-way file transfer (use pilot-share instead)
  - You need real-time streaming data (use pilot-stream-data instead)
  - Files are larger than 100MB without chunking support (use pilot-chunk-transfer)
tags:
  - pilot-protocol
  - file-transfer
  - synchronization
  - bidirectional
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

# pilot-sync

Bidirectional file synchronization between agents using conflict detection.

## Commands

### Sync directory to remote
```bash
for file in /path/to/sync/*; do
  pilotctl --json send-file 1:0001.AAAA.BBBB "$file"
done
```

### List received files
```bash
pilotctl --json received | jq -r '.received[] | {filename, size, from, timestamp}'
```

### Watch directory for changes
```bash
fswatch -0 /path/to/sync | while read -d "" file; do
  pilotctl --json send-file 1:0001.AAAA.BBBB "$file"
done
```

## Workflow Example

Bidirectional sync with conflict detection:

```bash
#!/bin/bash
SYNC_DIR="$HOME/shared-data"
REMOTE="1:0001.AAAA.BBBB"

# Build manifest
LOCAL_MANIFEST=$(find "$SYNC_DIR" -type f -exec sh -c \
  'printf "%s:%s:%s\n" "{}" "$(md5sum {} | cut -d\" \" -f1)" "$(stat -f %m {})"' \;)

# Send manifest and sync
pilotctl --json send-message "$REMOTE" --data "{\"type\":\"sync_init\",\"manifest\":\"$LOCAL_MANIFEST\"}"

# Start continuous sync
fswatch -0 "$SYNC_DIR" | while read -d "" changed_file; do
  pilotctl --json send-file "$REMOTE" "$changed_file"
done
```

## Dependencies

Requires pilot-protocol skill, jq, fswatch/inotifywait, md5sum, and stat.
