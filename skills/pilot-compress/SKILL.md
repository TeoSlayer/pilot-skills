---
name: pilot-compress
description: >
  Transparent compression for large messages over the Pilot Protocol network.

  Use this skill when:
  1. You need to reduce bandwidth for large payloads
  2. You want to send bulk messages efficiently
  3. You need compression for text or binary data

  Do NOT use this skill when:
  - You're sending small messages (overhead not worth it)
  - You need real-time streaming (compression adds latency)
  - Data is already compressed (images, videos, archives)
tags:
  - pilot-protocol
  - communication
  - compression
  - bandwidth
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

# pilot-compress

Transparent compression for large messages over the Pilot Protocol network. Automatically compresses and decompresses messages to reduce bandwidth usage, enabling efficient transmission of large text payloads, JSON data, and bulk messages.

## Commands

### Send message (compress manually before sending)

```bash
# Compress data before sending
DATA="large text payload here..."
COMPRESSED=$(echo "$DATA" | gzip | base64)
pilotctl --json send-message <hostname> --data "$COMPRESSED"
```

### Send file (compress before sending)

```bash
# Compress file before sending
gzip -c largefile.json > largefile.json.gz
pilotctl --json send-file <hostname> largefile.json.gz
```

### Receive and decompress

```bash
# Receive compressed data
INBOX=$(pilotctl --json inbox)
COMPRESSED_DATA=$(echo "$INBOX" | jq -r '.items[0].content')
echo "$COMPRESSED_DATA" | base64 -d | gunzip
```

## Workflow Example

Send large JSON report with compression:

```bash
#!/bin/bash
RECIPIENT="agent-b"
REPORT_FILE="analytics-report.json"

# Check original file size
ORIGINAL_SIZE=$(stat -f%z "$REPORT_FILE" 2>/dev/null || stat -c%s "$REPORT_FILE")
echo "Original size: $(($ORIGINAL_SIZE / 1024)) KB"

# Compress file
gzip -c "$REPORT_FILE" > "$REPORT_FILE.gz"

# Check compressed size
COMPRESSED_SIZE=$(stat -f%z "$REPORT_FILE.gz" 2>/dev/null || stat -c%s "$REPORT_FILE.gz")
echo "Compressed size: $(($COMPRESSED_SIZE / 1024)) KB"
echo "Compression ratio: $((ORIGINAL_SIZE / COMPRESSED_SIZE))x"

# Send compressed file
pilotctl --json send-file "$RECIPIENT" "$REPORT_FILE.gz"

# Cleanup
rm "$REPORT_FILE.gz"
```

Receiver decompresses:

```bash
# Receive file
pilotctl --json received

# Decompress received file
gunzip analytics-report.json.gz

# Or for piped data
INBOX=$(pilotctl --json inbox)
echo "$INBOX" | jq -r '.items[0].content' | base64 -d | gunzip > report.json
```

## Compression Formats

- **gzip**: Standard, widely compatible (gzip/gunzip)
- **zstd**: Better compression, faster (zstd -c file)
- **lz4**: Very fast, lower ratios (lz4 file)
- **brotli**: Excellent for text (brotli file)

## Dependencies

Requires pilot-protocol skill with running daemon and compression libraries (gzip, zstd, lz4, brotli).
