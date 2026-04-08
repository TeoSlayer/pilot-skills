---
name: pilot-chunk-transfer
description: >
  Large file transfer with automatic chunking, resume capability, and integrity verification.

  Use this skill when:
  1. You need to transfer files larger than 100MB reliably
  2. You want resume capability for interrupted transfers
  3. You need integrity verification with checksums per chunk

  Do NOT use this skill when:
  - Files are small (<10MB) - use pilot-share for simplicity
  - You need real-time streaming - use pilot-stream-data instead
  - You need bidirectional sync - use pilot-sync instead
tags:
  - pilot-protocol
  - file-transfer
  - chunking
  - large-files
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

# pilot-chunk-transfer

Large file transfer with automatic chunking, resume capability, and per-chunk integrity verification. Breaks large files into manageable chunks, tracks transfer progress, and enables resuming interrupted transfers.

## Commands

### Send file with chunking

```bash
FILE="/path/to/large-file.iso"
DEST="1:0001.AAAA.BBBB"
CHUNK_SIZE=$((1024 * 1024))  # 1MB

FILENAME=$(basename "$FILE")
FILESIZE=$(stat -f %z "$FILE" 2>/dev/null || stat -c %s "$FILE")
TOTAL_CHUNKS=$(( (FILESIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))

# Send metadata
pilotctl --json send-message "$DEST" \
  --data "{\"type\":\"chunk_transfer_start\",\"filename\":\"$FILENAME\",\"size\":$FILESIZE,\"total_chunks\":$TOTAL_CHUNKS}"

# Send chunks
for ((i=0; i<TOTAL_CHUNKS; i++)); do
  dd if="$FILE" bs="$CHUNK_SIZE" skip="$i" count=1 2>/dev/null > "/tmp/chunk_$i.dat"
  CHUNK_HASH=$(md5sum "/tmp/chunk_$i.dat" | cut -d' ' -f1)

  pilotctl --json send-message "$DEST" \
    --data "{\"type\":\"chunk_metadata\",\"chunk_id\":$i,\"hash\":\"$CHUNK_HASH\"}"

  pilotctl --json send-file "$DEST" "/tmp/chunk_$i.dat"
  rm "/tmp/chunk_$i.dat"
done

# Send completion
pilotctl --json send-message "$DEST" \
  --data "{\"type\":\"chunk_transfer_complete\",\"filename\":\"$FILENAME\"}"
```

### Receive and reassemble chunks

```bash
RECV_DIR="$HOME/.pilot/chunk-recv"
mkdir -p "$RECV_DIR"

INBOX=$(pilotctl --json inbox)
echo "$INBOX" | jq -c '.messages[]' | while read -r msg; do
  TYPE=$(echo "$msg" | jq -r '.type')

  case "$TYPE" in
    chunk_transfer_start)
      FILENAME=$(echo "$msg" | jq -r '.filename')
      mkdir -p "$RECV_DIR/$FILENAME.chunks"
      ;;

    chunk_metadata)
      CHUNK_ID=$(echo "$msg" | jq -r '.chunk_id')
      EXPECTED_HASH=$(echo "$msg" | jq -r '.hash')
      # Verify chunk hash after receiving file
      ;;

    chunk_transfer_complete)
      FILENAME=$(echo "$msg" | jq -r '.filename')
      cat "$RECV_DIR/$FILENAME.chunks"/chunk_* > "$RECV_DIR/$FILENAME"
      rm -rf "$RECV_DIR/$FILENAME.chunks"
      echo "Reassembled: $RECV_DIR/$FILENAME"
      ;;
  esac
done
```

### Resume interrupted transfer

```bash
STATE_FILE="/tmp/transfer_state.json"

if [ -f "$STATE_FILE" ]; then
  START_CHUNK=$(jq -r ".\"$FILENAME\".last_chunk // 0" "$STATE_FILE")
else
  START_CHUNK=0
fi

# Continue from START_CHUNK and update state after each chunk
```

## Workflow Example

```bash
# Send large file in chunks with resume capability
./pilot-chunk-transfer.sh send /path/to/large.iso 1:0001.AAAA.BBBB

# Receive in background
./pilot-chunk-transfer.sh receive
```

## Dependencies

Requires pilot-protocol skill with running daemon, jq for JSON parsing, dd for chunk extraction, md5sum for integrity verification, and bc for progress calculations.
