---
name: pilot-api-gateway-manager-setup
description: >
  Deploy an API gateway management system with 4 agents.

  Use this skill when:
  1. User wants to set up API gateway management with service discovery, routing, auth, and monitoring
  2. User is configuring agents for API request routing, rate limiting, or backend health tracking
  3. User asks about API gateway pipelines, service registries, or request authentication workflows

  Do NOT use this skill when:
  - User wants a single load balancer (use pilot-load-balancer instead)
  - User wants to verify a single token (use pilot-verify instead)
  - User only needs health checks (use pilot-health instead)
tags:
  - pilot-protocol
  - setup
  - api-gateway
  - microservices
  - routing
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

# API Gateway Manager Setup

Deploy 4 agents: discovery, router, auth, and monitor.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| discovery | `<prefix>-discovery` | pilot-discover, pilot-health, pilot-heartbeat-monitor | Registers backends, maintains service registry, health checks |
| router | `<prefix>-router` | pilot-load-balancer, pilot-task-router, pilot-metrics | Routes API requests by path, headers, and load |
| auth | `<prefix>-auth` | pilot-verify, pilot-audit-log, pilot-blocklist | Validates API keys/JWT, enforces rate limits and quotas |
| monitor | `<prefix>-monitor` | pilot-metrics, pilot-alert, pilot-slack-bridge | Tracks latency, error rates, throughput; alerts on anomalies |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For discovery:
clawhub install pilot-discover pilot-health pilot-heartbeat-monitor
# For router:
clawhub install pilot-load-balancer pilot-task-router pilot-metrics
# For auth:
clawhub install pilot-verify pilot-audit-log pilot-blocklist
# For monitor:
clawhub install pilot-metrics pilot-alert pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/api-gateway-manager.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### discovery
```json
{
  "setup": "api-gateway-manager", "setup_name": "API Gateway Manager",
  "role": "discovery", "role_name": "Service Discovery",
  "hostname": "<prefix>-discovery",
  "description": "Registers and discovers backend microservices, maintains service registry, runs health checks.",
  "skills": {"pilot-discover": "Register and discover backend microservice instances.", "pilot-health": "Run periodic health checks against registered backends.", "pilot-heartbeat-monitor": "Detect unresponsive backends via heartbeat timeouts."},
  "peers": [{"role": "router", "hostname": "<prefix>-router", "description": "Receives service registry updates"}, {"role": "monitor", "hostname": "<prefix>-monitor", "description": "Sends health feedback"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-router", "port": 1002, "topic": "service-registry", "description": "Service registry updates with healthy backends"}, {"direction": "receive", "peer": "<prefix>-monitor", "port": 1002, "topic": "health-feedback", "description": "Health feedback to deregister failing backends"}],
  "handshakes_needed": ["<prefix>-router", "<prefix>-monitor"]
}
```

### router
```json
{
  "setup": "api-gateway-manager", "setup_name": "API Gateway Manager",
  "role": "router", "role_name": "Request Router",
  "hostname": "<prefix>-router",
  "description": "Routes incoming API requests to appropriate backends based on path, headers, and load.",
  "skills": {"pilot-load-balancer": "Distribute requests across healthy backend instances.", "pilot-task-router": "Match request paths and headers to backend services.", "pilot-metrics": "Track routing decisions, request counts, and backend utilization."},
  "peers": [{"role": "discovery", "hostname": "<prefix>-discovery", "description": "Sends service registry updates"}, {"role": "auth", "hostname": "<prefix>-auth", "description": "Receives auth requests"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-discovery", "port": 1002, "topic": "service-registry", "description": "Service registry updates with healthy backends"}, {"direction": "send", "peer": "<prefix>-auth", "port": 1002, "topic": "auth-request", "description": "Auth requests for incoming API calls"}],
  "handshakes_needed": ["<prefix>-discovery", "<prefix>-auth"]
}
```

### auth
```json
{
  "setup": "api-gateway-manager", "setup_name": "API Gateway Manager",
  "role": "auth", "role_name": "Auth Gateway",
  "hostname": "<prefix>-auth",
  "description": "Validates API keys and JWT tokens, enforces rate limits and quotas, blocks bad actors.",
  "skills": {"pilot-verify": "Validate API keys and JWT tokens against trusted issuers.", "pilot-audit-log": "Log all access decisions with client metadata for compliance.", "pilot-blocklist": "Maintain and enforce blocklists for abusive clients and IPs."},
  "peers": [{"role": "router", "hostname": "<prefix>-router", "description": "Sends auth requests"}, {"role": "monitor", "hostname": "<prefix>-monitor", "description": "Receives access logs"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-router", "port": 1002, "topic": "auth-request", "description": "Auth requests for incoming API calls"}, {"direction": "send", "peer": "<prefix>-monitor", "port": 1002, "topic": "access-log", "description": "Access logs with auth decisions and client metadata"}],
  "handshakes_needed": ["<prefix>-router", "<prefix>-monitor"]
}
```

### monitor
```json
{
  "setup": "api-gateway-manager", "setup_name": "API Gateway Manager",
  "role": "monitor", "role_name": "API Monitor",
  "hostname": "<prefix>-monitor",
  "description": "Tracks latency, error rates, and throughput. Generates dashboards and alerts on anomalies.",
  "skills": {"pilot-metrics": "Compute latency percentiles, error rates, and throughput metrics.", "pilot-alert": "Fire alerts when error rates or latency exceed thresholds.", "pilot-slack-bridge": "Post API health summaries and incident alerts to Slack."},
  "peers": [{"role": "auth", "hostname": "<prefix>-auth", "description": "Sends access logs"}, {"role": "discovery", "hostname": "<prefix>-discovery", "description": "Receives health feedback"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-auth", "port": 1002, "topic": "access-log", "description": "Access logs with auth decisions"}, {"direction": "send", "peer": "<prefix>-discovery", "port": 1002, "topic": "health-feedback", "description": "Health feedback to deregister failing backends"}, {"direction": "send", "peer": "external", "port": 443, "topic": "api-alert", "description": "API alerts to ops dashboards and Slack"}],
  "handshakes_needed": ["<prefix>-auth", "<prefix>-discovery"]
}
```

## Data Flows

- `discovery -> router` : service-registry updates with healthy backends (port 1002)
- `router -> auth` : auth-request for incoming API calls (port 1002)
- `auth -> monitor` : access-log with auth decisions and client metadata (port 1002)
- `monitor -> discovery` : health-feedback to deregister failing backends (port 1002)
- `monitor -> external` : api-alert via Slack and dashboards (port 443)

## Handshakes

```bash
# discovery <-> router:
pilotctl --json handshake <prefix>-router "setup: api-gateway-manager"
pilotctl --json handshake <prefix>-discovery "setup: api-gateway-manager"
# router <-> auth:
pilotctl --json handshake <prefix>-auth "setup: api-gateway-manager"
pilotctl --json handshake <prefix>-router "setup: api-gateway-manager"
# auth <-> monitor:
pilotctl --json handshake <prefix>-monitor "setup: api-gateway-manager"
pilotctl --json handshake <prefix>-auth "setup: api-gateway-manager"
# monitor <-> discovery:
pilotctl --json handshake <prefix>-discovery "setup: api-gateway-manager"
pilotctl --json handshake <prefix>-monitor "setup: api-gateway-manager"
```

## Workflow Example

```bash
# On discovery -- publish service registry:
pilotctl --json publish <prefix>-router service-registry '{"service":"user-api","instances":[{"host":"10.0.1.5","port":8080,"health":"passing"}]}'
# On router -- publish auth request:
pilotctl --json publish <prefix>-auth auth-request '{"request_id":"req-88210","path":"/api/v2/users","api_key":"key_example_4eC39H"}'
# On auth -- publish access log:
pilotctl --json publish <prefix>-monitor access-log '{"request_id":"req-88210","client":"acme-corp","decision":"allow","latency_ms":12}'
# On monitor -- publish health feedback:
pilotctl --json publish <prefix>-discovery health-feedback '{"service":"user-api","instance":"10.0.1.6:8080","status":"failing","error_rate":0.42}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
