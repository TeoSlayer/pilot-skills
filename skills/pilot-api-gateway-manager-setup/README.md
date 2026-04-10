# API Gateway Manager

Deploy an API gateway management system with 4 agents that handle service discovery, request routing, authentication, and monitoring. A discovery agent registers backend microservices and tracks their health, a router distributes incoming requests based on path and load, an auth gateway validates credentials and enforces rate limits, and a monitor tracks latency and error rates while alerting on anomalies. The feedback loop from monitor to discovery enables automatic removal of unhealthy backends.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### discovery (Service Discovery)
Registers and discovers backend microservices, maintains a live service registry, and runs periodic health checks to detect failed or degraded backends.

**Skills:** pilot-discover, pilot-health, pilot-heartbeat-monitor

### router (Request Router)
Routes incoming API requests to appropriate backends based on path matching, header inspection, and current load distribution. Balances traffic across healthy instances.

**Skills:** pilot-load-balancer, pilot-task-router, pilot-metrics

### auth (Auth Gateway)
Validates API keys and JWT tokens, enforces per-client rate limits and quotas, and blocks known-bad actors. Logs all access decisions for audit compliance.

**Skills:** pilot-verify, pilot-audit-log, pilot-blocklist

### monitor (API Monitor)
Tracks request latency, error rates, and throughput across all backends. Generates dashboards and fires alerts when anomalies exceed configured thresholds.

**Skills:** pilot-metrics, pilot-alert, pilot-slack-bridge

## Data Flow

```
discovery --> router   : Service registry updates with healthy backends (port 1002)
router    --> auth     : Auth requests for incoming API calls (port 1002)
auth      --> monitor  : Access logs with auth decisions and client metadata (port 1002)
monitor   --> discovery: Health feedback to deregister failing backends (port 1002)
monitor   --> external : API alerts to ops dashboards and Slack (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (service discovery)
clawhub install pilot-discover pilot-health pilot-heartbeat-monitor
pilotctl set-hostname <your-prefix>-discovery

# On server 2 (request router)
clawhub install pilot-load-balancer pilot-task-router pilot-metrics
pilotctl set-hostname <your-prefix>-router

# On server 3 (auth gateway)
clawhub install pilot-verify pilot-audit-log pilot-blocklist
pilotctl set-hostname <your-prefix>-auth

# On server 4 (API monitor)
clawhub install pilot-metrics pilot-alert pilot-slack-bridge
pilotctl set-hostname <your-prefix>-monitor
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# discovery <-> router
# On discovery:
pilotctl handshake <your-prefix>-router "setup: api-gateway-manager"
# On router:
pilotctl handshake <your-prefix>-discovery "setup: api-gateway-manager"

# router <-> auth
# On router:
pilotctl handshake <your-prefix>-auth "setup: api-gateway-manager"
# On auth:
pilotctl handshake <your-prefix>-router "setup: api-gateway-manager"

# auth <-> monitor
# On auth:
pilotctl handshake <your-prefix>-monitor "setup: api-gateway-manager"
# On monitor:
pilotctl handshake <your-prefix>-auth "setup: api-gateway-manager"

# monitor <-> discovery (feedback loop)
# On monitor:
pilotctl handshake <your-prefix>-discovery "setup: api-gateway-manager"
# On discovery:
pilotctl handshake <your-prefix>-monitor "setup: api-gateway-manager"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-router -- subscribe to service registry updates:
pilotctl subscribe <your-prefix>-discovery service-registry

# On <your-prefix>-discovery -- publish a service registration:
pilotctl publish <your-prefix>-router service-registry '{"service":"user-api","version":"2.1.0","instances":[{"host":"10.0.1.5","port":8080,"health":"passing"},{"host":"10.0.1.6","port":8080,"health":"passing"}],"routes":["/api/v2/users/*"]}'

# On <your-prefix>-auth -- subscribe to auth requests from router:
pilotctl subscribe <your-prefix>-router auth-request

# On <your-prefix>-router -- publish an auth request:
pilotctl publish <your-prefix>-auth auth-request '{"request_id":"req-88210","path":"/api/v2/users/profile","method":"GET","api_key":"key_example_4eC39HqLyjWDarjtT1zdp7dc","client_ip":"203.0.113.42","headers":{"Authorization":"Bearer eyJhbGciOiJSUzI1NiJ9..."}}'

# On <your-prefix>-monitor -- subscribe to access logs from auth:
pilotctl subscribe <your-prefix>-auth access-log

# On <your-prefix>-auth -- publish an access log:
pilotctl publish <your-prefix>-monitor access-log '{"request_id":"req-88210","client":"acme-corp","decision":"allow","latency_ms":12,"rate_limit_remaining":847,"quota_used_pct":15.3}'

# On <your-prefix>-discovery -- subscribe to health feedback from monitor:
pilotctl subscribe <your-prefix>-monitor health-feedback

# On <your-prefix>-monitor -- publish health feedback:
pilotctl publish <your-prefix>-discovery health-feedback '{"service":"user-api","instance":"10.0.1.6:8080","status":"failing","error_rate":0.42,"p99_latency_ms":2800,"recommendation":"deregister"}'
```
