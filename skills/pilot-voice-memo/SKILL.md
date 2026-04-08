---
name: pilot-voice-memo
description: >
  Send audio file messages between agents over the Pilot Protocol network.

  Use this skill when:
  1. You need to send audio recordings or voice notes
  2. You want to transmit audio data between agents
  3. You need voice-based communication or audio file exchange

  Do NOT use this skill when:
  - You need text messages (use pilot-chat)
  - You need streaming audio (use pilot-connect)
  - You need video files (use pilot-send-file)
tags:
  - pilot-protocol
  - communication
  - audio
  - voice
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

# pilot-voice-memo

Send audio file messages between agents over the Pilot Protocol network. Enables voice-based communication through audio recordings, voice notes, and audio data exchange.

## Commands

### Record and send audio

```bash
# Record audio (example using arecord on Linux)
arecord -f cd -d 10 /tmp/voice-memo.wav

# Send the audio file
pilotctl --json send-file <hostname> /tmp/voice-memo.wav
```

### Receive audio files

Check for received files:

```bash
pilotctl --json received
```

### Clear received files

```bash
pilotctl --json received --clear
```

## Workflow Example

Send and receive voice memos:

```bash
#!/bin/bash
# Sender: Record and send
RECIPIENT="agent-b"
MEMO_FILE="/tmp/project-update-$(date +%Y%m%d-%H%M%S).wav"

# Record 10 seconds of audio
arecord -f cd -d 10 "$MEMO_FILE" 2>/dev/null

# Send file
pilotctl --json send-file "$RECIPIENT" "$MEMO_FILE"

rm "$MEMO_FILE"
echo "Voice memo sent to $RECIPIENT"

# Receiver: Check and download
FILES=$(pilotctl --json received)
echo "Received files:"
echo "$FILES" | jq -r '.files[]? | "\(.filename) from \(.sender)"'

# Files are automatically saved to local directory
# Play audio (Linux: aplay, macOS: afplay)
# aplay received-file.wav 2>/dev/null || afplay received-file.wav 2>/dev/null

# Clear after processing
pilotctl --json received --clear
```

## Audio Formats

- **WAV**: Uncompressed, high quality, large files
- **MP3**: Compressed, good quality, small files (recommended: 64kbps for voice)
- **Opus**: Better quality, ~240KB per minute at 32kbps

Convert to efficient format:

```bash
ffmpeg -i input.wav -codec:a libmp3lame -b:a 64k output.mp3 -y
```

## Dependencies

Requires pilot-protocol skill with running daemon, audio recording tool (arecord, sox, ffmpeg), audio playback tool (aplay, afplay, ffplay), and optional ffmpeg for conversion.
