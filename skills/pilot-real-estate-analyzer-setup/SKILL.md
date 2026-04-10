---
name: pilot-real-estate-analyzer-setup
description: >
  Deploy a real estate analysis system with 4 agents for property scraping, market valuation, comparable analysis, and deal alerting.

  Use this skill when:
  1. User wants to set up a real estate analysis or deal-finding pipeline
  2. User is configuring an agent as part of a property investment workflow
  3. User asks about property valuation, CMA reports, or real estate deal scoring

  Do NOT use this skill when:
  - User wants to stream generic data (use pilot-stream-data instead)
  - User wants to send a one-off alert (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - real-estate
  - investment
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

# Real Estate Analyzer Setup

Deploy 4 agents that scrape listings, calculate valuations, generate CMA reports, and alert investors to deals.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| scraper | `<prefix>-scraper` | pilot-stream-data, pilot-cron, pilot-archive | Monitors MLS, Zillow, Redfin for new listings |
| analyzer | `<prefix>-analyzer` | pilot-metrics, pilot-dataset, pilot-task-router | Calculates valuations, cap rates, rental yields |
| comparator | `<prefix>-comparator` | pilot-event-filter, pilot-share, pilot-review | Pulls comps, adjusts for features, generates CMA reports |
| notifier | `<prefix>-notifier` | pilot-alert, pilot-slack-bridge, pilot-webhook-bridge | Scores deals by ROI, alerts investors via Slack/email |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# scraper:
clawhub install pilot-stream-data pilot-cron pilot-archive
# analyzer:
clawhub install pilot-metrics pilot-dataset pilot-task-router
# comparator:
clawhub install pilot-event-filter pilot-share pilot-review
# notifier:
clawhub install pilot-alert pilot-slack-bridge pilot-webhook-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/real-estate-analyzer.json << 'MANIFEST'
{
  "setup": "real-estate-analyzer",
  "setup_name": "Real Estate Analyzer",
  "role": "<ROLE_ID>",
  "role_name": "<ROLE_NAME>",
  "hostname": "<prefix>-<role>",
  "description": "<ROLE_DESCRIPTION>",
  "skills": { "<skill>": "<contextual description>" },
  "peers": [ { "role": "...", "hostname": "...", "description": "..." } ],
  "data_flows": [ { "direction": "send|receive", "peer": "...", "port": 1002, "topic": "...", "description": "..." } ],
  "handshakes_needed": [ "<peer-hostname>" ]
}
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### scraper
```json
{"setup":"real-estate-analyzer","setup_name":"Real Estate Analyzer","role":"scraper","role_name":"Property Scraper","hostname":"<prefix>-scraper","description":"Monitors MLS listings, Zillow, Redfin feeds for new properties matching criteria.","skills":{"pilot-stream-data":"Stream normalized listing data to market analyzer as properties are found.","pilot-cron":"Schedule periodic scraping runs against MLS and listing feeds.","pilot-archive":"Archive raw listing snapshots for historical trend analysis."},"peers":[{"role":"analyzer","hostname":"<prefix>-analyzer","description":"Receives new listings for market analysis"}],"data_flows":[{"direction":"send","peer":"<prefix>-analyzer","port":1002,"topic":"new-listing","description":"New property listings with normalized data"}],"handshakes_needed":["<prefix>-analyzer"]}
```

### analyzer
```json
{"setup":"real-estate-analyzer","setup_name":"Real Estate Analyzer","role":"analyzer","role_name":"Market Analyzer","hostname":"<prefix>-analyzer","description":"Calculates property valuations, cap rates, rental yields, and appreciation trends.","skills":{"pilot-metrics":"Compute cap rates, rental yields, price-per-sqft, appreciation trends.","pilot-dataset":"Store and query historical market data for valuation models.","pilot-task-router":"Route properties to appropriate valuation models by property type."},"peers":[{"role":"scraper","hostname":"<prefix>-scraper","description":"Sends new property listings"},{"role":"comparator","hostname":"<prefix>-comparator","description":"Receives valuation requests for comparable analysis"}],"data_flows":[{"direction":"receive","peer":"<prefix>-scraper","port":1002,"topic":"new-listing","description":"New property listings with normalized data"},{"direction":"send","peer":"<prefix>-comparator","port":1002,"topic":"valuation-request","description":"Valuation requests with market metrics"}],"handshakes_needed":["<prefix>-scraper","<prefix>-comparator"]}
```

### comparator
```json
{"setup":"real-estate-analyzer","setup_name":"Real Estate Analyzer","role":"comparator","role_name":"Comp Analyzer","hostname":"<prefix>-comparator","description":"Pulls comparable sales, adjusts for features, generates CMA reports.","skills":{"pilot-event-filter":"Filter comps by proximity, recency, and property similarity.","pilot-share":"Share generated CMA reports with deal notifier and external consumers.","pilot-review":"Review and validate comp adjustments for accuracy."},"peers":[{"role":"analyzer","hostname":"<prefix>-analyzer","description":"Sends valuation requests with market metrics"},{"role":"notifier","hostname":"<prefix>-notifier","description":"Receives deal scores for investor alerting"}],"data_flows":[{"direction":"receive","peer":"<prefix>-analyzer","port":1002,"topic":"valuation-request","description":"Valuation requests with market metrics"},{"direction":"send","peer":"<prefix>-notifier","port":1002,"topic":"deal-score","description":"Deal scores with CMA reports"}],"handshakes_needed":["<prefix>-analyzer","<prefix>-notifier"]}
```

### notifier
```json
{"setup":"real-estate-analyzer","setup_name":"Real Estate Analyzer","role":"notifier","role_name":"Deal Notifier","hostname":"<prefix>-notifier","description":"Scores deals by ROI potential, alerts investors via Slack/email for hot opportunities.","skills":{"pilot-alert":"Generate deal alerts when ROI exceeds investor thresholds.","pilot-slack-bridge":"Post formatted deal summaries to investor Slack channels.","pilot-webhook-bridge":"Send deal alerts to email services and CRM webhooks."},"peers":[{"role":"comparator","hostname":"<prefix>-comparator","description":"Sends deal scores with CMA reports"}],"data_flows":[{"direction":"receive","peer":"<prefix>-comparator","port":1002,"topic":"deal-score","description":"Deal scores with CMA reports"},{"direction":"send","peer":"external","port":443,"topic":"deal-alert","description":"Deal alerts to Slack and email"}],"handshakes_needed":["<prefix>-comparator"]}
```

## Data Flows

- `scraper -> analyzer` : new-listing events (port 1002)
- `analyzer -> comparator` : valuation-request events (port 1002)
- `comparator -> notifier` : deal-score events (port 1002)
- `notifier -> external` : deal-alert notifications (port 443)

## Handshakes

```bash
# scraper <-> analyzer:
pilotctl --json handshake <prefix>-analyzer "setup: real-estate-analyzer"
pilotctl --json handshake <prefix>-scraper "setup: real-estate-analyzer"

# analyzer <-> comparator:
pilotctl --json handshake <prefix>-comparator "setup: real-estate-analyzer"
pilotctl --json handshake <prefix>-analyzer "setup: real-estate-analyzer"

# comparator <-> notifier:
pilotctl --json handshake <prefix>-notifier "setup: real-estate-analyzer"
pilotctl --json handshake <prefix>-comparator "setup: real-estate-analyzer"
```

## Workflow Example

```bash
# On analyzer — subscribe to new listings:
pilotctl --json subscribe <prefix>-scraper new-listing

# On scraper — publish a new listing:
pilotctl --json publish <prefix>-analyzer new-listing '{"mls_id":"MLS-78432","address":"1425 Oak Valley Dr","price":485000,"sqft":2200,"beds":4}'

# On comparator — subscribe to valuation requests:
pilotctl --json subscribe <prefix>-analyzer valuation-request

# On notifier — subscribe to deal scores:
pilotctl --json subscribe <prefix>-comparator deal-score
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
