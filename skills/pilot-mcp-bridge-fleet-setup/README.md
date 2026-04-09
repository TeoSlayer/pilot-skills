# MCP Bridge Fleet Setup

Bridge different agent ecosystems over Pilot tunnels. An MCP gateway exposes MCP-compatible tool servers, an A2A bridge connects Google A2A agents, and a tool registry lets agents discover available capabilities across protocols. All traffic is encrypted and trust-gated.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### mcp-gw (MCP Gateway)
Bridges MCP tool servers onto the Pilot network. Agents can call MCP tools through encrypted tunnels without exposing HTTP endpoints.

**Skills:** pilot-mcp-bridge, pilot-api-gateway, pilot-health, pilot-metrics

### a2a-bridge (A2A Bridge)
Connects Google A2A protocol agents to the Pilot network. Routes tasks between A2A and Pilot agents transparently.

**Skills:** pilot-a2a-bridge, pilot-task-router, pilot-audit-log

### tool-registry (Tool Registry)
Central directory where MCP tools, A2A agents, and native Pilot skills register their capabilities. Other agents query it to discover what tools are available.

**Skills:** pilot-directory, pilot-discover, pilot-announce-capabilities, pilot-load-balancer

## Data Flow

```
mcp-gw        --> tool-registry : Registers available MCP tools (port 1002)
a2a-bridge    --> tool-registry : Registers available A2A agents (port 1002)
tool-registry --> mcp-gw        : Routes tool calls to MCP servers (port 1002)
tool-registry --> a2a-bridge    : Routes tasks to A2A agents (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On MCP gateway node
clawhub install pilot-mcp-bridge pilot-api-gateway pilot-health pilot-metrics
pilotctl set-hostname <your-prefix>-mcp-gw

# On A2A bridge node
clawhub install pilot-a2a-bridge pilot-task-router pilot-audit-log
pilotctl set-hostname <your-prefix>-a2a-bridge

# On tool registry node
clawhub install pilot-directory pilot-discover pilot-announce-capabilities pilot-load-balancer
pilotctl set-hostname <your-prefix>-tool-registry
```

### 2. Establish trust

Both bridges trust the registry. Each bridge handshakes the registry, and the registry handshakes each bridge. Auto-approved when mutual.

```bash
# mcp-gw <-> tool-registry
# On mcp-gw:
pilotctl handshake <your-prefix>-tool-registry "mcp bridge fleet"
# On tool-registry:
pilotctl handshake <your-prefix>-mcp-gw "mcp bridge fleet"

# a2a-bridge <-> tool-registry
# On a2a-bridge:
pilotctl handshake <your-prefix>-tool-registry "mcp bridge fleet"
# On tool-registry:
pilotctl handshake <your-prefix>-a2a-bridge "mcp bridge fleet"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-mcp-gw — register an MCP tool:
pilotctl publish <your-prefix>-tool-registry tool-register '{"name":"web-search","protocol":"mcp","provider":"<your-prefix>-mcp-gw","schema":{"query":"string"}}'

# On <your-prefix>-a2a-bridge — register an A2A agent:
pilotctl publish <your-prefix>-tool-registry tool-register '{"name":"code-review","protocol":"a2a","provider":"<your-prefix>-a2a-bridge","schema":{"repo":"string","pr":"number"}}'

# On <your-prefix>-tool-registry — route a tool call to MCP:
pilotctl publish <your-prefix>-mcp-gw tool-call '{"call_id":"C-401","tool":"web-search","params":{"query":"Pilot Protocol docs"}}'

# On <your-prefix>-mcp-gw — return result:
pilotctl publish <your-prefix>-tool-registry tool-result '{"call_id":"C-401","result":{"url":"https://pilotprotocol.network","title":"Pilot Protocol"}}'
```
