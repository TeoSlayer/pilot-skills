# Competitor Intelligence

Deploy a multi-agent competitive intelligence system that crawls competitor websites, analyzes market trends, tracks changes over time, and routes actionable alerts to your team. Each agent handles a stage of the intelligence pipeline, from raw data collection through analysis to prioritized notifications.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### crawler (Web Crawler)
Scrapes competitor websites, pricing pages, product launches, and press releases.

**Skills:** pilot-stream-data, pilot-archive, pilot-cron

### analyzer (Market Analyzer)
Processes crawled data, identifies trends, price changes, and feature gaps.

**Skills:** pilot-event-filter, pilot-metrics, pilot-task-router

### tracker (Change Tracker)
Maintains historical records, detects significant changes, scores threat levels.

**Skills:** pilot-audit-log, pilot-dataset, pilot-alert

### alerter (Intelligence Alerter)
Routes actionable intelligence to Slack, email, and dashboards based on severity.

**Skills:** pilot-slack-bridge, pilot-webhook-bridge, pilot-announce

## Data Flow

```
crawler  --> analyzer : Crawled data from competitor sites (port 1002)
analyzer --> tracker  : Market insights and trend analysis (port 1002)
tracker  --> alerter  : Change alerts with threat scores (port 1002)
alerter  --> external : Intelligence reports via Slack and webhooks (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (web crawler)
clawhub install pilot-stream-data pilot-archive pilot-cron
pilotctl set-hostname <your-prefix>-crawler

# On server 2 (market analyzer)
clawhub install pilot-event-filter pilot-metrics pilot-task-router
pilotctl set-hostname <your-prefix>-analyzer

# On server 3 (change tracker)
clawhub install pilot-audit-log pilot-dataset pilot-alert
pilotctl set-hostname <your-prefix>-tracker

# On server 4 (intelligence alerter)
clawhub install pilot-slack-bridge pilot-webhook-bridge pilot-announce
pilotctl set-hostname <your-prefix>-alerter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On crawler:
pilotctl handshake <your-prefix>-analyzer "setup: competitor-intelligence"
# On analyzer:
pilotctl handshake <your-prefix>-crawler "setup: competitor-intelligence"
# On analyzer:
pilotctl handshake <your-prefix>-tracker "setup: competitor-intelligence"
# On tracker:
pilotctl handshake <your-prefix>-analyzer "setup: competitor-intelligence"
# On tracker:
pilotctl handshake <your-prefix>-alerter "setup: competitor-intelligence"
# On alerter:
pilotctl handshake <your-prefix>-tracker "setup: competitor-intelligence"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-analyzer — subscribe to crawled data from crawler:
pilotctl subscribe <your-prefix>-crawler crawled-data

# On <your-prefix>-tracker — subscribe to market insights from analyzer:
pilotctl subscribe <your-prefix>-analyzer market-insight

# On <your-prefix>-alerter — subscribe to change alerts from tracker:
pilotctl subscribe <your-prefix>-tracker change-alert

# On <your-prefix>-crawler — publish crawled data:
pilotctl publish <your-prefix>-analyzer crawled-data '{"competitor":"RivalCorp","url":"https://rivalcorp.com/pricing","type":"pricing_page","products":[{"name":"Pro Plan","price":49.99,"was":59.99}]}'

# On <your-prefix>-analyzer — publish a market insight:
pilotctl publish <your-prefix>-tracker market-insight '{"competitor":"RivalCorp","insight":"price_decrease","product":"Pro Plan","change_pct":-16.7,"trend":"aggressive_pricing"}'

# On <your-prefix>-tracker — publish a change alert:
pilotctl publish <your-prefix>-alerter change-alert '{"competitor":"RivalCorp","threat_score":8,"change":"Pro Plan price cut 16.7%","historical_context":"3rd price cut in 6 months","recommendation":"review_pricing_strategy"}'

# On <your-prefix>-alerter — forward intelligence report:
pilotctl publish <your-prefix>-alerter intelligence-report '{"channel":"#competitive-intel","severity":"high","summary":"RivalCorp aggressive pricing: Pro Plan down 16.7%","action_required":true}'
```
