---
name: pilot-api-gateway
description: >
  Expose local APIs to the Pilot Protocol network.

  Use this skill when:
  1. You need to expose local APIs to remote Pilot agents
  2. You want to provide API access without public internet exposure
  3. You're building API-based agent services on Pilot

  Do NOT use this skill when:
  - APIs are already publicly accessible
  - You need HTTP-only proxying (use pilot-http-proxy instead)
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - api
  - gateway
  - rest
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

# Pilot API Gateway

Expose local APIs to the Pilot Protocol network through gateway mode or custom messaging.

## Commands

### Start Gateway (HTTP/HTTPS)
```bash
pilotctl --json gateway start
```

### Map Remote API
```bash
pilotctl --json gateway map <hostname> <local-ip>
```

### Listen for Custom API Requests
```bash
pilotctl --json listen 80
```

### Send API Response
```bash
pilotctl --json send-message <client> --data "<response>"
```

## Workflow Example

```bash
#!/bin/bash
# Custom API server via messaging

pilotctl --json daemon start --hostname data-api --public
pilotctl --json listen 80

while true; do
  REQUEST=$(pilotctl --json recv 80 --timeout 120s)
  METHOD=$(echo "$REQUEST" | jq -r '.method // "GET"')
  PATH=$(echo "$REQUEST" | jq -r '.path // "/"')
  SENDER=$(echo "$REQUEST" | jq -r '.sender')

  case "$METHOD:$PATH" in
    "GET:/api/status")
      RESPONSE='{"status":"ok"}'
      ;;
    "GET:/api/users")
      RESPONSE='[{"id":1,"name":"Alice"}]'
      ;;
    *)
      RESPONSE='{"error":"not found"}'
      ;;
  esac

  pilotctl --json send-message "$SENDER" --data "$RESPONSE"
done
```

## Dependencies

Requires pilot-protocol skill, running daemon, and local API server.
