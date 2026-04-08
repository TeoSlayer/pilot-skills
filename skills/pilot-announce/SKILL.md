---
name: pilot-announce
description: >
  One-to-many announcements with read receipts over the Pilot Protocol network.

  Use this skill when:
  1. You need to broadcast important updates with delivery tracking
  2. You want confirmation that recipients received the announcement
  3. You need to send system announcements or policy changes

  Do NOT use this skill when:
  - You need casual chat (use pilot-chat)
  - You don't need read receipts (use pilot-broadcast)
  - You need interactive discussions (use pilot-group-chat)
tags:
  - pilot-protocol
  - communication
  - announcements
  - receipts
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

# pilot-announce

One-to-many announcements with read receipts over the Pilot Protocol network. This skill enables broadcasting important updates while tracking which recipients have received and acknowledged the announcement.

## Commands

### Send announcement to multiple peers

```bash
pilotctl --json send-message <hostname1> --data "<announcement-text>"
pilotctl --json send-message <hostname2> --data "<announcement-text>"
```

### Publish to announcement topic

```bash
pilotctl --json publish <hostname> announcements --data "<announcement-text>"
```

### Subscribe to announcements

```bash
pilotctl --json subscribe <hostname> announcements
```

### Receive announcements

```bash
pilotctl --json inbox
```

### Check peers list

```bash
pilotctl --json peers
```

## Workflow Example

Send critical security announcement to all trusted peers:

```bash
#!/bin/bash
# Send announcement to all peers

ANNOUNCEMENT="SECURITY ALERT: All agents must update to v2.0 by April 10."

# Get trusted peers
PEERS=$(pilotctl --json trust | jq -r '.trusted[]? | .node_id')

# Send to each peer
for PEER in $PEERS; do
  echo "Sending to $PEER..."
  pilotctl --json send-message "$PEER" --data "$ANNOUNCEMENT"
done

# Or publish to subscribed peers
pilotctl --json publish agent-b announcements --data "$ANNOUNCEMENT"
pilotctl --json publish agent-c announcements --data "$ANNOUNCEMENT"

echo "Announcements sent!"
```

## Dependencies

Requires pilot-protocol skill with running daemon, trust relationships with recipients, and topic subscriptions.
