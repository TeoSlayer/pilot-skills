---
name: pilot-mcp-bridge-fleet-setup
description: >
  Deploy an MCP and A2A bridge fleet with 3 agents.

  Use this skill when:
  1. User wants to bridge MCP servers or A2A agents onto the Pilot network
  2. User is configuring an MCP gateway, A2A bridge, or tool registry agent
  3. User asks about connecting different agent ecosystems over Pilot tunnels

  Do NOT use this skill when:
  - User wants a single MCP bridge (use pilot-mcp-bridge instead)
  - User wants a single A2A connection (use pilot-a2a-bridge instead)
tags:
  - pilot-protocol
  - setup
  - mcp
  - interoperability
license: AGPL-3.0
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - clawhub
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# MCP Bridge Fleet Setup

Deploy 3 agents: MCP gateway, A2A bridge, and tool registry.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| mcp-gateway | `<prefix>-mcp-gw` | pilot-mcp-bridge, pilot-api-gateway, pilot-health, pilot-metrics | Bridges MCP tool servers |
| a2a-bridge | `<prefix>-a2a-bridge` | pilot-a2a-bridge, pilot-task-router, pilot-audit-log | Connects A2A protocol agents |
| tool-registry | `<prefix>-tool-registry` | pilot-directory, pilot-discover, pilot-announce-capabilities, pilot-load-balancer | Central tool directory |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# mcp-gateway:
clawhub install pilot-mcp-bridge pilot-api-gateway pilot-health pilot-metrics
# a2a-bridge:
clawhub install pilot-a2a-bridge pilot-task-router pilot-audit-log
# tool-registry:
clawhub install pilot-directory pilot-discover pilot-announce-capabilities pilot-load-balancer
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/mcp-bridge-fleet.json`.

**Step 4:** Both bridges handshake the registry.

## Manifest Templates Per Role

### mcp-gateway
```json
{
  "setup": "mcp-bridge-fleet", "role": "mcp-gateway", "role_name": "MCP Gateway",
  "hostname": "<prefix>-mcp-gw",
  "skills": {
    "pilot-mcp-bridge": "Bridge MCP tool servers onto the Pilot network.",
    "pilot-api-gateway": "Accept tool calls from Pilot agents.",
    "pilot-health": "Monitor MCP server availability.",
    "pilot-metrics": "Track tool call throughput and latency."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-tool-registry", "port": 1002, "topic": "tool-register", "description": "Register MCP tools" },
    { "direction": "receive", "peer": "<prefix>-tool-registry", "port": 1002, "topic": "tool-call", "description": "Incoming tool calls" },
    { "direction": "send", "peer": "<prefix>-tool-registry", "port": 1002, "topic": "tool-result", "description": "Tool call results" }
  ],
  "handshakes_needed": ["<prefix>-tool-registry"]
}
```

### a2a-bridge
```json
{
  "setup": "mcp-bridge-fleet", "role": "a2a-bridge", "role_name": "A2A Bridge",
  "hostname": "<prefix>-a2a-bridge",
  "skills": {
    "pilot-a2a-bridge": "Connect Google A2A protocol agents to Pilot.",
    "pilot-task-router": "Route tasks between A2A and Pilot agents.",
    "pilot-audit-log": "Log all cross-protocol task routing."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-tool-registry", "port": 1002, "topic": "tool-register", "description": "Register A2A agents" },
    { "direction": "receive", "peer": "<prefix>-tool-registry", "port": 1002, "topic": "tool-call", "description": "Incoming task routes" }
  ],
  "handshakes_needed": ["<prefix>-tool-registry"]
}
```

### tool-registry
```json
{
  "setup": "mcp-bridge-fleet", "role": "tool-registry", "role_name": "Tool Registry",
  "hostname": "<prefix>-tool-registry",
  "skills": {
    "pilot-directory": "Central directory of all available tools.",
    "pilot-discover": "Serve capability queries from agents.",
    "pilot-announce-capabilities": "Accept tool registrations from bridges.",
    "pilot-load-balancer": "Balance tool calls across multiple providers."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-mcp-gw", "port": 1002, "topic": "tool-register", "description": "MCP tool registrations" },
    { "direction": "receive", "peer": "<prefix>-a2a-bridge", "port": 1002, "topic": "tool-register", "description": "A2A agent registrations" },
    { "direction": "send", "peer": "<prefix>-mcp-gw", "port": 1002, "topic": "tool-call", "description": "Route tool calls to MCP" },
    { "direction": "send", "peer": "<prefix>-a2a-bridge", "port": 1002, "topic": "tool-call", "description": "Route tasks to A2A" }
  ],
  "handshakes_needed": ["<prefix>-mcp-gw", "<prefix>-a2a-bridge"]
}
```

## Data Flows

- `mcp-gateway → tool-registry` : MCP tool registrations (port 1002)
- `a2a-bridge → tool-registry` : A2A agent registrations (port 1002)
- `tool-registry → mcp-gateway` : tool call routing (port 1002)
- `tool-registry → a2a-bridge` : task routing (port 1002)

## Workflow Example

```bash
# On mcp-gateway — register a tool:
pilotctl --json publish <prefix>-tool-registry tool-register '{"name":"web-search","protocol":"mcp"}'
# On tool-registry — route a call:
pilotctl --json publish <prefix>-mcp-gw tool-call '{"call_id":"C-401","tool":"web-search","params":{"query":"Pilot Protocol"}}'
# On mcp-gateway — return result:
pilotctl --json publish <prefix>-tool-registry tool-result '{"call_id":"C-401","result":{"url":"https://pilotprotocol.network"}}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
