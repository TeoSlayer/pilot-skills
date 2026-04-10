---
name: pilot-media-monitoring-setup
description: >
  Deploy a media monitoring and intelligence platform with 4 agents.

  Use this skill when:
  1. User wants to set up coordinated media crawling, sentiment analysis, trend detection, and reporting agents
  2. User is configuring a brand monitoring, share-of-voice tracking, or PR crisis detection workflow
  3. User asks about media intelligence pipelines, sentiment scoring, or automated media briefings

  Do NOT use this skill when:
  - User wants a single RSS or news feed (use pilot-stream-data instead)
  - User wants to send a one-off Slack notification (use pilot-slack-bridge instead)
  - User only needs event filtering without the full pipeline (use pilot-event-filter instead)
tags:
  - pilot-protocol
  - setup
  - media
  - monitoring
  - sentiment
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

# Media Monitoring Setup

Deploy 4 agents: crawler, sentiment-analyzer, trend-detector, and reporter.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| crawler | `<prefix>-crawler` | pilot-stream-data, pilot-cron, pilot-archive | Scrapes news, social media, and blogs for mentions |
| sentiment-analyzer | `<prefix>-sentiment-analyzer` | pilot-event-filter, pilot-metrics, pilot-task-router | Classifies mentions by sentiment and reach |
| trend-detector | `<prefix>-trend-detector` | pilot-dataset, pilot-alert, pilot-gossip | Identifies viral content and PR crises |
| reporter | `<prefix>-reporter` | pilot-slack-bridge, pilot-webhook-bridge, pilot-announce | Generates briefings and crisis dashboards |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For crawler:
clawhub install pilot-stream-data pilot-cron pilot-archive
# For sentiment-analyzer:
clawhub install pilot-event-filter pilot-metrics pilot-task-router
# For trend-detector:
clawhub install pilot-dataset pilot-alert pilot-gossip
# For reporter:
clawhub install pilot-slack-bridge pilot-webhook-bridge pilot-announce
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/media-monitoring.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

**Step 5:** Verify connectivity with `pilotctl --json trust`.

## Manifest Templates Per Role

### crawler
```json
{"setup":"media-monitoring","role":"crawler","role_name":"Media Crawler","hostname":"<prefix>-crawler","skills":{"pilot-stream-data":"Ingest content from news sites, social media, and RSS feeds.","pilot-cron":"Schedule periodic crawl sweeps across configured sources.","pilot-archive":"Store raw mention data for historical analysis."},"data_flows":[{"direction":"send","peer":"<prefix>-sentiment-analyzer","port":1002,"topic":"media-mention","description":"Raw media mentions with source metadata"}],"handshakes_needed":["<prefix>-sentiment-analyzer"]}
```

### sentiment-analyzer
```json
{"setup":"media-monitoring","role":"sentiment-analyzer","role_name":"Sentiment Analyzer","hostname":"<prefix>-sentiment-analyzer","skills":{"pilot-event-filter":"Classify mentions by sentiment polarity and confidence.","pilot-metrics":"Track sentiment trends, mention volume, and influencer reach.","pilot-task-router":"Route analysis jobs across content types."},"data_flows":[{"direction":"receive","peer":"<prefix>-crawler","port":1002,"topic":"media-mention","description":"Raw mentions from crawler"},{"direction":"send","peer":"<prefix>-trend-detector","port":1002,"topic":"scored-mention","description":"Scored mentions with sentiment and reach"}],"handshakes_needed":["<prefix>-crawler","<prefix>-trend-detector"]}
```

### trend-detector
```json
{"setup":"media-monitoring","role":"trend-detector","role_name":"Trend Detector","hostname":"<prefix>-trend-detector","skills":{"pilot-dataset":"Store time-series share-of-voice and trend velocity data.","pilot-alert":"Emit alerts when crisis thresholds or viral velocity are breached.","pilot-gossip":"Share trend signals across detection nodes for consensus."},"data_flows":[{"direction":"receive","peer":"<prefix>-sentiment-analyzer","port":1002,"topic":"scored-mention","description":"Scored mentions from analyzer"},{"direction":"send","peer":"<prefix>-reporter","port":1002,"topic":"trend-alert","description":"Trend alerts and crisis warnings"}],"handshakes_needed":["<prefix>-sentiment-analyzer","<prefix>-reporter"]}
```

### reporter
```json
{"setup":"media-monitoring","role":"reporter","role_name":"Media Reporter","hostname":"<prefix>-reporter","skills":{"pilot-slack-bridge":"Send media briefings and crisis alerts to Slack channels.","pilot-webhook-bridge":"Push reports to external dashboards and BI tools.","pilot-announce":"Broadcast summary reports to subscribed stakeholders."},"data_flows":[{"direction":"receive","peer":"<prefix>-trend-detector","port":1002,"topic":"trend-alert","description":"Trend alerts from detector"},{"direction":"send","peer":"external","port":443,"topic":"media-briefing","description":"Formatted media briefings"}],"handshakes_needed":["<prefix>-trend-detector"]}
```

## Data Flows

- `crawler -> sentiment-analyzer` : raw media mentions with source metadata (port 1002)
- `sentiment-analyzer -> trend-detector` : scored mentions with sentiment and reach (port 1002)
- `trend-detector -> reporter` : trend alerts and crisis warnings (port 1002)
- `reporter -> external` : media briefings via secure channel (port 443)

## Handshakes

```bash
pilotctl --json handshake <prefix>-sentiment-analyzer "setup: media-monitoring"
pilotctl --json handshake <prefix>-crawler "setup: media-monitoring"
pilotctl --json handshake <prefix>-trend-detector "setup: media-monitoring"
pilotctl --json handshake <prefix>-reporter "setup: media-monitoring"
```

## Workflow Example

```bash
# On crawler -- publish media mention:
pilotctl --json publish <prefix>-sentiment-analyzer media-mention '{"source":"reuters","headline":"Acme Corp reports record Q1","reach":2400000}'
# On sentiment-analyzer -- publish scored mention:
pilotctl --json publish <prefix>-trend-detector scored-mention '{"headline":"Acme Corp reports record Q1","sentiment":"positive","score":0.87}'
# On trend-detector -- publish trend alert:
pilotctl --json publish <prefix>-reporter trend-alert '{"brand":"acme","trend":"earnings_beat","velocity":340,"severity":"info"}'
# On reporter -- distribute briefing:
pilotctl --json publish <prefix>-reporter media-briefing '{"period":"daily","total_mentions":1847,"sentiment_positive":0.68}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
