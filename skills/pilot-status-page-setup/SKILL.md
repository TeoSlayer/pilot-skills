---
name: pilot-status-page-setup
description: >
  Deploy a status page pipeline with 3 agents that automate service monitoring,
  status aggregation, and public incident communication.

  Use this skill when:
  1. User wants to set up a status page or service monitoring pipeline
  2. User is configuring an agent as part of an uptime or incident management workflow
  3. User asks about automating health checks, status aggregation, or incident notifications

  Do NOT use this skill when:
  - User wants a simple health check (use pilot-health instead)
  - User wants a one-off alert notification (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - status-page
  - monitoring
  - incidents
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

# Status Page Setup

Deploy 3 agents that automate service monitoring, status aggregation, and incident communication.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| monitor | `<prefix>-monitor` | pilot-health, pilot-cron, pilot-metrics | Pings endpoints, checks response times, detects outages |
| aggregator | `<prefix>-aggregator` | pilot-event-filter, pilot-dataset, pilot-audit-log | Combines health checks into system status, tracks uptime |
| publisher | `<prefix>-publisher` | pilot-webhook-bridge, pilot-announce, pilot-slack-bridge | Updates status page, sends incident notifications |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For monitor:
clawhub install pilot-health pilot-cron pilot-metrics

# For aggregator:
clawhub install pilot-event-filter pilot-dataset pilot-audit-log

# For publisher:
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/status-page.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### monitor
```json
{"setup":"status-page","setup_name":"Status Page","role":"monitor","role_name":"Service Monitor","hostname":"<prefix>-monitor","description":"Pings endpoints, checks response times, detects outages and degradation.","skills":{"pilot-health":"Run HTTP/TCP health checks against configured service endpoints.","pilot-cron":"Schedule health checks at regular intervals (e.g. every 30 seconds).","pilot-metrics":"Track response times, error rates, and availability per service."},"peers":[{"role":"aggregator","hostname":"<prefix>-aggregator","description":"Receives health check results for status aggregation"}],"data_flows":[{"direction":"send","peer":"<prefix>-aggregator","port":1002,"topic":"health-check","description":"Per-service health check results"}],"handshakes_needed":["<prefix>-aggregator"]}
```

### aggregator
```json
{"setup":"status-page","setup_name":"Status Page","role":"aggregator","role_name":"Status Aggregator","hostname":"<prefix>-aggregator","description":"Combines health checks into overall system status, tracks uptime percentages, maintains incident history.","skills":{"pilot-event-filter":"Filter health events by severity and detect incident-worthy degradation.","pilot-dataset":"Store uptime history, incident records, and historical status snapshots.","pilot-audit-log":"Log all status transitions and incident lifecycle events for audit."},"peers":[{"role":"monitor","hostname":"<prefix>-monitor","description":"Sends health check results"},{"role":"publisher","hostname":"<prefix>-publisher","description":"Receives status updates and incident events"}],"data_flows":[{"direction":"receive","peer":"<prefix>-monitor","port":1002,"topic":"health-check","description":"Per-service health check results"},{"direction":"send","peer":"<prefix>-publisher","port":1002,"topic":"status-update","description":"System status updates and incident events"}],"handshakes_needed":["<prefix>-monitor","<prefix>-publisher"]}
```

### publisher
```json
{"setup":"status-page","setup_name":"Status Page","role":"publisher","role_name":"Status Publisher","hostname":"<prefix>-publisher","description":"Updates public status page, sends incident notifications to subscribers via email and Slack.","skills":{"pilot-webhook-bridge":"Push status updates and incident events to the public status page API.","pilot-announce":"Broadcast incident notifications to all registered subscribers.","pilot-slack-bridge":"Post incident updates and resolution notices to operations Slack channels."},"peers":[{"role":"aggregator","hostname":"<prefix>-aggregator","description":"Sends status updates and incident events"}],"data_flows":[{"direction":"receive","peer":"<prefix>-aggregator","port":1002,"topic":"status-update","description":"System status updates and incident events"},{"direction":"send","peer":"external","port":443,"topic":"incident-notification","description":"Incident notifications to subscribers"}],"handshakes_needed":["<prefix>-aggregator"]}
```

## Data Flows

- `monitor -> aggregator` : health-check events (port 1002)
- `aggregator -> publisher` : status-update events (port 1002)
- `publisher -> external` : incident-notification via webhook (port 443)

## Handshakes

```bash
# monitor <-> aggregator:
pilotctl --json handshake <prefix>-aggregator "setup: status-page"
pilotctl --json handshake <prefix>-monitor "setup: status-page"
# aggregator <-> publisher:
pilotctl --json handshake <prefix>-publisher "setup: status-page"
pilotctl --json handshake <prefix>-aggregator "setup: status-page"
```

## Workflow Example

```bash
# On aggregator -- subscribe to health checks:
pilotctl --json subscribe <prefix>-monitor health-check
# On publisher -- subscribe to status updates:
pilotctl --json subscribe <prefix>-aggregator status-update
# On monitor -- publish a health check:
pilotctl --json publish <prefix>-aggregator health-check '{"service":"api-gateway","status":"degraded","response_ms":2340,"threshold_ms":500}'
# On aggregator -- publish status update:
pilotctl --json publish <prefix>-publisher status-update '{"overall_status":"degraded","incident":true,"incident_id":"INC-2025-0018","affected_services":["api-gateway"]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
