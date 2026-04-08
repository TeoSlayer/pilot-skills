---
name: pilot-mcp-bridge
description: >
  MCP server wrapping the Pilot daemon for OpenClaw/Claude Code integration.

  Use this skill when:
  1. You need to expose Pilot Protocol operations as MCP tools
  2. You want to integrate Pilot into Claude Code or OpenClaw workflows
  3. You're building an AI agent that needs to communicate over Pilot

  Do NOT use this skill when:
  - You need direct pilotctl access (use pilot-protocol skill instead)
  - The daemon is not running
  - You're working in a non-MCP environment
tags:
  - pilot-protocol
  - integration
  - mcp
  - bridge
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

# Pilot MCP Bridge

Blueprint for wrapping Pilot Protocol as MCP server for Claude Code/OpenClaw integration.

## MCP Tools to Expose

Identity & Status:
- `pilot_daemon_status`: Run `pilotctl --json daemon status`
- `pilot_info`: Run `pilotctl --json info`
- `pilot_peers`: Run `pilotctl --json peers`

Communication:
- `pilot_connect`: Run `pilotctl --json connect <target> <port> --message "<msg>"`
- `pilot_send_message`: Run `pilotctl --json send-message <target> --data "<msg>"`
- `pilot_recv`: Run `pilotctl --json recv <port>`
- `pilot_listen`: Run `pilotctl --json listen <port>`

Discovery:
- `pilot_find`: Run `pilotctl --json find <hostname>`
- `pilot_lookup`: Run `pilotctl --json lookup <node_id>`

Pub/Sub:
- `pilot_publish`: Run `pilotctl --json publish <target> <topic> --data "<msg>"`
- `pilot_subscribe`: Run `pilotctl --json subscribe <target> <topic>`

Gateway:
- `pilot_gateway_start`: Run `pilotctl --json gateway start`
- `pilot_gateway_map`: Run `pilotctl --json gateway map <hostname> <local-ip>`

## Workflow Example

```bash
# Start Pilot daemon
pilotctl --json daemon start --registry 34.71.57.205:9000 --beacon 34.71.57.205:9001

# Start MCP server wrapper
python mcp_pilot_server.py

# MCP tools now available in Claude Code/OpenClaw
```

## Dependencies

Requires pilot-protocol skill, pilotctl binary, MCP server framework (Python mcp library), and MCP-compatible client.
