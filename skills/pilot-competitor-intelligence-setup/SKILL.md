---
name: pilot-competitor-intelligence-setup
description: >
  Deploy a competitive intelligence system with 4 agents for crawling, analysis, tracking, and alerting.

  Use this skill when:
  1. User wants to set up competitor monitoring or market intelligence
  2. User is configuring an agent as part of a competitive intelligence setup
  3. User asks about web crawling, market analysis, or competitor tracking across agents

  Do NOT use this skill when:
  - User wants to stream a single data feed (use pilot-stream-data instead)
  - User wants to send a one-off Slack message (use pilot-slack-bridge instead)
tags:
  - pilot-protocol
  - setup
  - intelligence
  - competitive-analysis
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

# Competitor Intelligence Setup

Deploy 4 agents that crawl competitor sites, analyze trends, track changes, and route intelligence alerts.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| crawler | `<prefix>-crawler` | pilot-stream-data, pilot-archive, pilot-cron | Scrapes competitor websites, pricing pages, press releases |
| analyzer | `<prefix>-analyzer` | pilot-event-filter, pilot-metrics, pilot-task-router | Processes crawled data, identifies trends and feature gaps |
| tracker | `<prefix>-tracker` | pilot-audit-log, pilot-dataset, pilot-alert | Maintains history, detects changes, scores threat levels |
| alerter | `<prefix>-alerter` | pilot-slack-bridge, pilot-webhook-bridge, pilot-announce | Routes intelligence to Slack, email, dashboards by severity |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For crawler:
clawhub install pilot-stream-data pilot-archive pilot-cron
# For analyzer:
clawhub install pilot-event-filter pilot-metrics pilot-task-router
# For tracker:
clawhub install pilot-audit-log pilot-dataset pilot-alert
# For alerter:
clawhub install pilot-slack-bridge pilot-webhook-bridge pilot-announce
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/competitor-intelligence.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### crawler
```json
{
  "setup": "competitor-intelligence", "setup_name": "Competitor Intelligence",
  "role": "crawler", "role_name": "Web Crawler",
  "hostname": "<prefix>-crawler",
  "description": "Scrapes competitor websites, pricing pages, product launches, and press releases.",
  "skills": {"pilot-stream-data": "Stream crawled pages and pricing data to analyzer.", "pilot-archive": "Archive raw HTML snapshots for historical comparison.", "pilot-cron": "Schedule crawl jobs on configurable intervals."},
  "peers": [{"role": "analyzer", "hostname": "<prefix>-analyzer", "description": "Receives crawled data for analysis"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-analyzer", "port": 1002, "topic": "crawled-data", "description": "Crawled data from competitor sites"}],
  "handshakes_needed": ["<prefix>-analyzer"]
}
```

### analyzer
```json
{
  "setup": "competitor-intelligence", "setup_name": "Competitor Intelligence",
  "role": "analyzer", "role_name": "Market Analyzer",
  "hostname": "<prefix>-analyzer",
  "description": "Processes crawled data, identifies trends, price changes, and feature gaps.",
  "skills": {"pilot-event-filter": "Filter noise and irrelevant changes from crawled data.", "pilot-metrics": "Compute trend metrics: price deltas, feature counts, market share estimates.", "pilot-task-router": "Route different insight types to appropriate tracking categories."},
  "peers": [{"role": "crawler", "hostname": "<prefix>-crawler", "description": "Sends crawled data"}, {"role": "tracker", "hostname": "<prefix>-tracker", "description": "Receives market insights"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-crawler", "port": 1002, "topic": "crawled-data", "description": "Crawled data from competitor sites"}, {"direction": "send", "peer": "<prefix>-tracker", "port": 1002, "topic": "market-insight", "description": "Market insights and trend analysis"}],
  "handshakes_needed": ["<prefix>-crawler", "<prefix>-tracker"]
}
```

### tracker
```json
{
  "setup": "competitor-intelligence", "setup_name": "Competitor Intelligence",
  "role": "tracker", "role_name": "Change Tracker",
  "hostname": "<prefix>-tracker",
  "description": "Maintains historical records, detects significant changes, scores threat levels.",
  "skills": {"pilot-audit-log": "Log all detected changes with timestamps and diffs.", "pilot-dataset": "Store historical competitor data for trend comparison.", "pilot-alert": "Alert when threat scores exceed configurable thresholds."},
  "peers": [{"role": "analyzer", "hostname": "<prefix>-analyzer", "description": "Sends market insights"}, {"role": "alerter", "hostname": "<prefix>-alerter", "description": "Receives change alerts"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-analyzer", "port": 1002, "topic": "market-insight", "description": "Market insights and trend analysis"}, {"direction": "send", "peer": "<prefix>-alerter", "port": 1002, "topic": "change-alert", "description": "Change alerts with threat scores"}],
  "handshakes_needed": ["<prefix>-analyzer", "<prefix>-alerter"]
}
```

### alerter
```json
{
  "setup": "competitor-intelligence", "setup_name": "Competitor Intelligence",
  "role": "alerter", "role_name": "Intelligence Alerter",
  "hostname": "<prefix>-alerter",
  "description": "Routes actionable intelligence to Slack, email, and dashboards based on severity.",
  "skills": {"pilot-slack-bridge": "Post intelligence summaries to Slack channels by severity.", "pilot-webhook-bridge": "Forward reports to dashboards and email services via webhooks.", "pilot-announce": "Broadcast critical intelligence to all subscribed stakeholders."},
  "peers": [{"role": "tracker", "hostname": "<prefix>-tracker", "description": "Sends change alerts with threat scores"}],
  "data_flows": [{"direction": "receive", "peer": "<prefix>-tracker", "port": 1002, "topic": "change-alert", "description": "Change alerts with threat scores"}, {"direction": "send", "peer": "external", "port": 443, "topic": "intelligence-report", "description": "Intelligence reports via Slack and webhooks"}],
  "handshakes_needed": ["<prefix>-tracker"]
}
```

## Data Flows

- `crawler -> analyzer` : crawled-data events (port 1002)
- `analyzer -> tracker` : market-insight events (port 1002)
- `tracker -> alerter` : change-alert events (port 1002)
- `alerter -> external` : intelligence-report via webhook (port 443)

## Handshakes

```bash
# crawler <-> analyzer:
pilotctl --json handshake <prefix>-analyzer "setup: competitor-intelligence"
pilotctl --json handshake <prefix>-crawler "setup: competitor-intelligence"
# analyzer <-> tracker:
pilotctl --json handshake <prefix>-tracker "setup: competitor-intelligence"
pilotctl --json handshake <prefix>-analyzer "setup: competitor-intelligence"
# tracker <-> alerter:
pilotctl --json handshake <prefix>-alerter "setup: competitor-intelligence"
pilotctl --json handshake <prefix>-tracker "setup: competitor-intelligence"
```

## Workflow Example

```bash
# On analyzer — subscribe to crawled data:
pilotctl --json subscribe <prefix>-crawler crawled-data
# On tracker — subscribe to market insights:
pilotctl --json subscribe <prefix>-analyzer market-insight
# On alerter — subscribe to change alerts:
pilotctl --json subscribe <prefix>-tracker change-alert
# On crawler — publish crawled data:
pilotctl --json publish <prefix>-analyzer crawled-data '{"competitor":"RivalCorp","url":"https://rivalcorp.com/pricing","type":"pricing_page"}'
# On tracker — publish a change alert:
pilotctl --json publish <prefix>-alerter change-alert '{"competitor":"RivalCorp","threat_score":8,"change":"Pro Plan price cut 16.7%"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
