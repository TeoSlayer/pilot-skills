---
name: pilot-ad-campaign-manager-setup
description: >
  Deploy an ad campaign management system with 4 agents that automate
  campaign strategy, creative production, real-time bidding, and performance analytics.

  Use this skill when:
  1. User wants to set up an automated ad campaign management pipeline
  2. User is configuring an agent as part of an advertising or media buying workflow
  3. User asks about automating campaign strategy, creative testing, or bid optimization across agents

  Do NOT use this skill when:
  - User wants to track a single metric (use pilot-metrics instead)
  - User wants a one-off data stream (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - advertising
  - campaigns
  - bidding
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

# Ad Campaign Manager Setup

Deploy 4 agents that automate ad campaigns from strategy through bidding to performance analysis.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| strategist | `<prefix>-strategist` | pilot-task-router, pilot-dataset, pilot-cron | Defines audiences, budgets, channel mix, and KPIs |
| creative | `<prefix>-creative` | pilot-share, pilot-task-parallel, pilot-receipt | Generates ad copy, headlines, and A/B test variations |
| bidder | `<prefix>-bidder` | pilot-metrics, pilot-stream-data, pilot-escrow | Manages real-time bidding and spend optimization |
| analyst | `<prefix>-analyst` | pilot-event-filter, pilot-slack-bridge, pilot-webhook-bridge | Tracks conversions, ROAS, CTR; feeds insights back to strategist |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# strategist:
clawhub install pilot-task-router pilot-dataset pilot-cron
# creative:
clawhub install pilot-share pilot-task-parallel pilot-receipt
# bidder:
clawhub install pilot-metrics pilot-stream-data pilot-escrow
# analyst:
clawhub install pilot-event-filter pilot-slack-bridge pilot-webhook-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/ad-campaign-manager.json << 'MANIFEST'
<USE ROLE TEMPLATE BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### strategist
```json
{"setup":"ad-campaign-manager","setup_name":"Ad Campaign Manager","role":"strategist","role_name":"Campaign Strategist","hostname":"<prefix>-strategist","description":"Defines target audiences, budgets, channel mix, and KPIs for ad campaigns.","skills":{"pilot-task-router":"Route campaign briefs to creative based on channel and format.","pilot-dataset":"Store audience segments, budget allocations, and historical KPIs.","pilot-cron":"Schedule campaign launches and budget review cycles."},"peers":[{"role":"creative","hostname":"<prefix>-creative","description":"Receives campaign briefs and produces ad variations"},{"role":"analyst","hostname":"<prefix>-analyst","description":"Sends performance insights and optimization recommendations"}],"data_flows":[{"direction":"send","peer":"<prefix>-creative","port":1002,"topic":"campaign-brief","description":"Campaign briefs with audiences, budgets, and KPIs"},{"direction":"receive","peer":"<prefix>-analyst","port":1002,"topic":"performance-insight","description":"Performance insights and optimization recommendations"}],"handshakes_needed":["<prefix>-creative","<prefix>-analyst"]}
```

### creative
```json
{"setup":"ad-campaign-manager","setup_name":"Ad Campaign Manager","role":"creative","role_name":"Creative Producer","hostname":"<prefix>-creative","description":"Generates ad copy, headlines, and creative briefs. A/B tests variations across formats.","skills":{"pilot-share":"Send creative assets downstream to the bid manager.","pilot-task-parallel":"Run A/B test variations in parallel across formats.","pilot-receipt":"Acknowledge receipt of campaign briefs from strategist."},"peers":[{"role":"strategist","hostname":"<prefix>-strategist","description":"Sends campaign briefs"},{"role":"bidder","hostname":"<prefix>-bidder","description":"Receives creative assets for bidding"}],"data_flows":[{"direction":"receive","peer":"<prefix>-strategist","port":1002,"topic":"campaign-brief","description":"Campaign briefs with audiences, budgets, and KPIs"},{"direction":"send","peer":"<prefix>-bidder","port":1002,"topic":"creative-asset","description":"Creative assets with A/B variants and targeting params"}],"handshakes_needed":["<prefix>-strategist","<prefix>-bidder"]}
```

### bidder
```json
{"setup":"ad-campaign-manager","setup_name":"Ad Campaign Manager","role":"bidder","role_name":"Bid Manager","hostname":"<prefix>-bidder","description":"Manages real-time bidding, adjusts bids based on performance, optimizes spend across channels.","skills":{"pilot-metrics":"Track bid performance — CPM, CPC, conversion rates per channel.","pilot-stream-data":"Stream real-time auction data and bid adjustments.","pilot-escrow":"Manage budget holds and spend reconciliation across channels."},"peers":[{"role":"creative","hostname":"<prefix>-creative","description":"Sends creative assets"},{"role":"analyst","hostname":"<prefix>-analyst","description":"Receives bid results for analysis"}],"data_flows":[{"direction":"receive","peer":"<prefix>-creative","port":1002,"topic":"creative-asset","description":"Creative assets with A/B variants and targeting params"},{"direction":"send","peer":"<prefix>-analyst","port":1002,"topic":"bid-result","description":"Bid results with spend, impressions, and click data"}],"handshakes_needed":["<prefix>-creative","<prefix>-analyst"]}
```

### analyst
```json
{"setup":"ad-campaign-manager","setup_name":"Ad Campaign Manager","role":"analyst","role_name":"Performance Analyst","hostname":"<prefix>-analyst","description":"Tracks conversions, ROAS, CTR. Generates reports and optimization recommendations.","skills":{"pilot-event-filter":"Filter bid events by channel, campaign, and performance threshold.","pilot-slack-bridge":"Post campaign performance summaries and alerts to Slack.","pilot-webhook-bridge":"Push campaign reports to external dashboards and stakeholders."},"peers":[{"role":"bidder","hostname":"<prefix>-bidder","description":"Sends bid results"},{"role":"strategist","hostname":"<prefix>-strategist","description":"Receives performance insights for campaign refinement"}],"data_flows":[{"direction":"receive","peer":"<prefix>-bidder","port":1002,"topic":"bid-result","description":"Bid results with spend, impressions, and click data"},{"direction":"send","peer":"<prefix>-strategist","port":1002,"topic":"performance-insight","description":"Performance insights and optimization recommendations"},{"direction":"send","peer":"external","port":443,"topic":"campaign-report","description":"Campaign reports to dashboards and stakeholders"}],"handshakes_needed":["<prefix>-bidder","<prefix>-strategist"]}
```

## Data Flows

- `strategist -> creative` : campaign-brief (port 1002)
- `creative -> bidder` : creative-asset (port 1002)
- `bidder -> analyst` : bid-result (port 1002)
- `analyst -> strategist` : performance-insight (port 1002)
- `analyst -> external` : campaign-report via webhook (port 443)

## Handshakes

```bash
# strategist <-> creative:
pilotctl --json handshake <prefix>-creative "setup: ad-campaign-manager"
pilotctl --json handshake <prefix>-strategist "setup: ad-campaign-manager"
# creative <-> bidder:
pilotctl --json handshake <prefix>-bidder "setup: ad-campaign-manager"
pilotctl --json handshake <prefix>-creative "setup: ad-campaign-manager"
# bidder <-> analyst:
pilotctl --json handshake <prefix>-analyst "setup: ad-campaign-manager"
pilotctl --json handshake <prefix>-bidder "setup: ad-campaign-manager"
# analyst <-> strategist (feedback loop):
pilotctl --json handshake <prefix>-strategist "setup: ad-campaign-manager"
pilotctl --json handshake <prefix>-analyst "setup: ad-campaign-manager"
```

## Workflow Example

```bash
# On creative -- subscribe to campaign briefs:
pilotctl --json subscribe <prefix>-strategist campaign-brief
# On bidder -- subscribe to creative assets:
pilotctl --json subscribe <prefix>-creative creative-asset
# On analyst -- subscribe to bid results:
pilotctl --json subscribe <prefix>-bidder bid-result
# On strategist -- subscribe to performance insights:
pilotctl --json subscribe <prefix>-analyst performance-insight
# On strategist -- publish a campaign brief:
pilotctl --json publish <prefix>-creative campaign-brief '{"campaign":"Summer Sale 2026","audience":{"age":"25-45"},"budget":15000,"channels":["google","meta"]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
