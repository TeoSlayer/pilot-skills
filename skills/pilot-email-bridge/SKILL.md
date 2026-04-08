---
name: pilot-email-bridge
description: >
  Send and receive emails via Pilot Protocol messaging.

  Use this skill when:
  1. You need to send email notifications from Pilot agents
  2. You want to receive emails as Pilot events
  3. You're integrating agents with email-based workflows

  Do NOT use this skill when:
  - You need real-time messaging (use native Pilot instead)
  - Email server is not configured
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - email
  - bridge
  - notifications
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

# pilot-email-bridge

Send and receive emails via Pilot Protocol messaging using external SMTP/IMAP tools with Pilot webhooks.

## Commands

### Configure Outbound Webhook
```bash
pilotctl --json set-webhook https://smtp-relay.example.com/send
```

### Send Email via Webhook
```bash
pilotctl --json publish localhost email-outbound --data '{"to":"user@example.com","subject":"Alert","body":"Status OK"}'
```

### Check Inbox
```bash
pilotctl --json inbox
pilotctl --json inbox --clear
```

### Receive Messages
```bash
pilotctl --json recv 1004 --count 10
```

### Send File Attachment
```bash
pilotctl --json send-file email-relay /path/to/report.pdf
```

## Workflow Example

```bash
#!/bin/bash
# SMTP relay setup

pilotctl --json daemon start --hostname email-relay
pilotctl --json set-webhook http://localhost:8025/smtp
pilotctl --json subscribe localhost email-outbound

# Start external SMTP relay server
python3 smtp_relay_server.py &

# Publish email
pilotctl --json publish localhost email-outbound --data '{
  "to":"admin@example.com",
  "subject":"Report",
  "body":"All systems operational"
}'
```

## Dependencies

Requires pilot-protocol skill, running daemon, SMTP server, and email credentials.
