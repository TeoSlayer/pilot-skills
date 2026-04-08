---
name: pilot-http-proxy
description: >
  Route HTTP requests through Pilot Protocol tunnels.

  Use this skill when:
  1. You need to access HTTP services behind NATs or firewalls
  2. You want to proxy HTTP traffic through the Pilot overlay network
  3. You're exposing local HTTP servers to remote agents

  Do NOT use this skill when:
  - Services are already publicly accessible
  - You need direct HTTP access on the same network
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - http
  - proxy
  - gateway
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

# Pilot HTTP Proxy

Route HTTP requests through Pilot Protocol tunnels using the gateway subsystem.

## Commands

### Start Gateway
```bash
pilotctl --json gateway start
```

### Map Remote HTTP Service
```bash
pilotctl --json gateway map <hostname> <local-ip>
```

### List Mappings
```bash
pilotctl --json gateway list
```

### Remove Mapping
```bash
pilotctl --json gateway unmap <local-ip>
```

### Stop Gateway
```bash
pilotctl --json gateway stop
```

## Workflow Example

```bash
#!/bin/bash
# Access remote HTTP API

pilotctl --json daemon start
pilotctl --json find api-server
pilotctl --json gateway start
pilotctl --json gateway map api-server 192.168.100.50

# Access remote service
curl http://192.168.100.50/api/v1/status
curl http://192.168.100.50:8080/metrics
```

## Port Mapping

Gateway forwards common HTTP ports:
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 8080 (alternative HTTP)

## Dependencies

Requires pilot-protocol skill with running daemon. Root/sudo on Linux for port <1024.
