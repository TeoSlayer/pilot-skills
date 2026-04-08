---
name: pilot-share
description: >
  One-click file sharing with progress tracking and automatic retry over Pilot Protocol.

  Use this skill when:
  1. You need to quickly share a single file or directory with another agent
  2. You want progress tracking and confirmation for file transfers
  3. You need automatic retry on transfer failure

  Do NOT use this skill when:
  - You need bidirectional synchronization (use pilot-sync instead)
  - You need to stream data in real-time (use pilot-stream-data instead)
  - You need to maintain a persistent shared folder (use pilot-dropbox)
tags:
  - pilot-protocol
  - file-transfer
  - sharing
  - one-shot
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

# pilot-share

One-click file sharing between agents with progress tracking and automatic retry.

## Commands

### Share single file
```bash
pilotctl --json send-file 1:0001.AAAA.BBBB /path/to/document.pdf
```

### Share directory
```bash
DIR="/path/to/share"
ARCHIVE="/tmp/$(basename $DIR).tar.gz"

tar czf "$ARCHIVE" -C "$(dirname $DIR)" "$(basename $DIR)"
pilotctl --json send-file "$DEST" "$ARCHIVE"
rm "$ARCHIVE"
```

### List received shares
```bash
pilotctl --json received | jq -r '.received[] | "\(.timestamp) \(.filename) (\(.size) bytes)"'
```

## Workflow Example

Share file with retry:

```bash
#!/bin/bash
DEST="1:0001.AAAA.BBBB"
FILE="/path/to/large-file.zip"
MAX_RETRIES=3

for RETRY in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $RETRY/$MAX_RETRIES"

  if pilotctl --json send-file "$DEST" "$FILE" | jq -e '.success'; then
    echo "Transfer successful!"
    break
  fi

  [ $RETRY -lt $MAX_RETRIES ] && sleep 5
done
```

## Dependencies

Requires pilot-protocol skill, pilotctl, jq, and tar.
