---
name: pilot-archive
description: >
  Index and search historical data exchanges, messages, and file transfers over Pilot Protocol.

  Use this skill when:
  1. You need to search through past messages and file transfers
  2. You want to maintain searchable history of all agent communications
  3. You need to audit or analyze historical data exchange patterns

  Do NOT use this skill when:
  - You need real-time data access (use pilot-stream-data instead)
  - You need active file synchronization (use pilot-sync instead)
  - You need current inbox messages (use pilotctl inbox directly)
tags:
  - pilot-protocol
  - archive
  - search
  - history
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

# pilot-archive

Index and search historical data exchanges including messages, file transfers, and communication patterns. This skill provides a searchable archive of all Pilot Protocol communications with metadata indexing, full-text search, and analytics capabilities.

## Commands

### Index Messages
Build searchable index of message history:
```bash
ARCHIVE_DIR="$HOME/.pilot/archive"
INDEX_FILE="$ARCHIVE_DIR/message-index.jsonl"
mkdir -p "$ARCHIVE_DIR"

pilotctl --json inbox | jq -c '.messages[] |
  {timestamp, from, type, content, indexed_at: (now | todate)}' >> "$INDEX_FILE"
```

### Index File Transfers
Record file transfer history:
```bash
ARCHIVE_DIR="$HOME/.pilot/archive"
FILE_INDEX="$ARCHIVE_DIR/file-index.jsonl"

pilotctl --json received | jq -c '.received[] |
  {timestamp, from, filename, size, port, indexed_at: (now | todate)}' >> "$FILE_INDEX"
```

### Search Messages
Full-text search through message archive:
```bash
KEYWORD="$1"
jq -r "select(.content | test(\"$KEYWORD\"; \"i\")) |
  \"[\(.timestamp)] \(.from): \(.content)\"" "$HOME/.pilot/archive/message-index.jsonl"
```

### Search by Sender
Find all communications from specific agent:
```bash
SENDER="1:0001.AAAA.BBBB"
jq -r "select(.from == \"$SENDER\") |
  \"[\(.timestamp)] \(.type): \(.content)\"" \
  "$HOME/.pilot/archive/message-index.jsonl"
```

### Archive Statistics
Generate statistics from archive:
```bash
ARCHIVE_DIR="$HOME/.pilot/archive"
MSG_COUNT=$(wc -l < "$ARCHIVE_DIR/message-index.jsonl")
FILE_COUNT=$(wc -l < "$ARCHIVE_DIR/file-index.jsonl")

echo "Total messages: $MSG_COUNT"
echo "Total files: $FILE_COUNT"
echo ""
echo "Top senders:"
jq -r '.from' "$ARCHIVE_DIR/message-index.jsonl" | sort | uniq -c | sort -rn | head -5
```

## Workflow Example

```bash
#!/bin/bash
# pilot-archive: Historical data indexing and search

ARCHIVE_DIR="$HOME/.pilot/archive"
MSG_INDEX="$ARCHIVE_DIR/message-index.jsonl"
FILE_INDEX="$ARCHIVE_DIR/file-index.jsonl"

mkdir -p "$ARCHIVE_DIR"

# Index messages (get all, filter client-side)
pilotctl --json inbox | jq -c '.messages[] |
  {timestamp, from, to, type, content, indexed_at: (now | todate)}' | tail -100 >> "$MSG_INDEX"

# Index files (get all, filter client-side)
pilotctl --json received | jq -c '.received[] |
  {timestamp, from, filename, size, port, indexed_at: (now | todate)}' | tail -100 >> "$FILE_INDEX"

# Search archive
search_query="$1"
if [ -n "$search_query" ]; then
  echo "=== Messages ==="
  jq -r "select(.content | test(\"$search_query\"; \"i\")) |
    \"[\(.timestamp)] \(.from): \(.content)\"" "$MSG_INDEX" | head -20
fi
```

## Dependencies

Requires pilot-protocol, jq, tar/gzip for export.
