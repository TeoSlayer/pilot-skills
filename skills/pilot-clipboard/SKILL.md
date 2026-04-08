---
name: pilot-clipboard
description: >
  Shared clipboard for quick text and data snippets between agents over Pilot Protocol.

  Use this skill when:
  1. You need to share short text snippets or command output between agents
  2. You want a quick copy/paste mechanism across the Pilot network
  3. You need to exchange small data payloads without file transfer

  Do NOT use this skill when:
  - You need to transfer files (use pilot-share instead)
  - You need to share large datasets (use pilot-dataset instead)
  - You need persistent storage (use pilot-backup instead)
tags:
  - pilot-protocol
  - clipboard
  - text-sharing
  - quick-exchange
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

# pilot-clipboard

Shared clipboard for exchanging text snippets and command output between agents.

## Commands

### Copy to Remote Clipboard
```bash
echo "Hello from Pilot!" | pilotctl --json send "1:0001.AAAA.BBBB" 1001 --data "$(cat)"
```

### Send Message
```bash
pilotctl --json send-message "1:0001.AAAA.BBBB" --data "Hello from Pilot!"
```

### Paste from Remote
```bash
pilotctl --json inbox | jq -r '.messages[0].content'
```

### Share Command Output
```bash
OUTPUT=$(ls -lh)
pilotctl --json send "1:0001.AAAA.BBBB" 1001 --data "$OUTPUT"
```

## Workflow Example

```bash
#!/bin/bash
# Clipboard manager

CLIPBOARD_PORT=1001

clip_copy() {
  local dest="$1"
  local content="${2:-$(cat)}"
  local sender=$(pilotctl --json info | jq -r '.hostname')

  local clip_msg=$(cat <<EOF
{"type":"clipboard","content":$(echo "$content" | jq -R -s .),"sender":"$sender"}
EOF
)

  pilotctl --json send-message "$dest" --data "$clip_msg"
}

clip_paste() {
  pilotctl --json inbox | jq -r '.messages[] | select(.type == "clipboard") | .content' | head -1
}

case "${1:-help}" in
  copy) shift; clip_copy "$@" ;;
  paste) clip_paste ;;
  *) echo "Usage: pilot-clipboard {copy DEST [CONTENT]|paste}" ;;
esac
```

## Dependencies

Requires pilot-protocol, pilotctl, and jq. Clipboard tools: pbcopy/pbpaste (macOS) or xclip/xsel (Linux).
