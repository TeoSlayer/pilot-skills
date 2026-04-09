---
name: pilot-financial-trading-desk-setup
description: >
  Deploy a financial trading desk with 4 agents.

  Use this skill when:
  1. User wants to set up coordinated market analysis, sentiment, risk management, and execution agents
  2. User is configuring an automated or semi-automated trading workflow
  3. User asks about trade signal pipelines, risk checks, or execution management

  Do NOT use this skill when:
  - User wants a single market data feed (use pilot-stream-data instead)
  - User wants to send a one-off price alert (use pilot-alert instead)
  - User only needs a webhook to an exchange API (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - trading
  - finance
  - risk-management
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

# Financial Trading Desk Setup

Deploy 4 agents: analyst, sentiment, risk-mgr, and executor.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| analyst | `<prefix>-analyst` | pilot-stream-data, pilot-metrics, pilot-cron, pilot-alert | Monitors markets, identifies trading opportunities |
| sentiment | `<prefix>-sentiment` | pilot-stream-data, pilot-event-filter, pilot-archive | Scans news and social media for sentiment signals |
| risk-mgr | `<prefix>-risk-mgr` | pilot-event-filter, pilot-audit-log, pilot-alert | Evaluates trades against portfolio risk limits |
| executor | `<prefix>-executor` | pilot-task-router, pilot-receipt, pilot-webhook-bridge | Executes approved trades, reports fills |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For analyst:
clawhub install pilot-stream-data pilot-metrics pilot-cron pilot-alert
# For sentiment:
clawhub install pilot-stream-data pilot-event-filter pilot-archive
# For risk-mgr:
clawhub install pilot-event-filter pilot-audit-log pilot-alert
# For executor:
clawhub install pilot-task-router pilot-receipt pilot-webhook-bridge
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/financial-trading-desk.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

## Manifest Templates Per Role

### analyst
```json
{
  "setup": "financial-trading-desk", "role": "analyst", "role_name": "Market Analyst",
  "hostname": "<prefix>-analyst",
  "skills": {
    "pilot-stream-data": "Ingest real-time market data feeds (price, volume, order book).",
    "pilot-metrics": "Track signal accuracy, win rate, and Sharpe ratio.",
    "pilot-cron": "Run scheduled scans for technical setups across watchlists.",
    "pilot-alert": "Emit trade signals when high-confidence setups are detected."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-risk-mgr", "port": 1002, "topic": "trade-signal", "description": "Trade signals with entry/exit levels" }
  ],
  "handshakes_needed": ["<prefix>-risk-mgr"]
}
```

### sentiment
```json
{
  "setup": "financial-trading-desk", "role": "sentiment", "role_name": "Sentiment Scanner",
  "hostname": "<prefix>-sentiment",
  "skills": {
    "pilot-stream-data": "Ingest news feeds, social media streams, and earnings data.",
    "pilot-event-filter": "Classify content as bullish, bearish, or neutral.",
    "pilot-archive": "Store historical sentiment data for backtesting."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-risk-mgr", "port": 1002, "topic": "sentiment-score", "description": "Sentiment scores with source attribution" }
  ],
  "handshakes_needed": ["<prefix>-risk-mgr"]
}
```

### risk-mgr
```json
{
  "setup": "financial-trading-desk", "role": "risk-mgr", "role_name": "Risk Manager",
  "hostname": "<prefix>-risk-mgr",
  "skills": {
    "pilot-event-filter": "Correlate trade signals with sentiment for confirmation.",
    "pilot-audit-log": "Log all risk decisions with full reasoning for audit.",
    "pilot-alert": "Emit alerts on exposure limit breaches or drawdown warnings."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-analyst", "port": 1002, "topic": "trade-signal", "description": "Trade signals from analyst" },
    { "direction": "receive", "peer": "<prefix>-sentiment", "port": 1002, "topic": "sentiment-score", "description": "Sentiment scores from scanner" },
    { "direction": "send", "peer": "<prefix>-executor", "port": 1002, "topic": "approved-trade", "description": "Approved trades with position sizing" },
    { "direction": "receive", "peer": "<prefix>-executor", "port": 1002, "topic": "execution-report", "description": "Fill reports for P&L tracking" }
  ],
  "handshakes_needed": ["<prefix>-analyst", "<prefix>-sentiment", "<prefix>-executor"]
}
```

### executor
```json
{
  "setup": "financial-trading-desk", "role": "executor", "role_name": "Trade Executor",
  "hostname": "<prefix>-executor",
  "skills": {
    "pilot-task-router": "Route orders to optimal execution venue.",
    "pilot-receipt": "Generate trade confirmations and settlement receipts.",
    "pilot-webhook-bridge": "Interface with exchange APIs for order placement."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-risk-mgr", "port": 1002, "topic": "approved-trade", "description": "Approved trades to execute" },
    { "direction": "send", "peer": "<prefix>-risk-mgr", "port": 1002, "topic": "execution-report", "description": "Fill reports with price and slippage" }
  ],
  "handshakes_needed": ["<prefix>-risk-mgr"]
}
```

## Data Flows

- `analyst -> risk-mgr` : trade signals with entry/exit levels and rationale (port 1002)
- `sentiment -> risk-mgr` : sentiment scores with source attribution (port 1002)
- `risk-mgr -> executor` : approved trades with position size and risk parameters (port 1002)
- `executor -> risk-mgr` : execution reports with fill price and slippage (port 1002)

## Workflow Example

```bash
# On analyst -- detect setup and publish signal:
pilotctl --json publish <prefix>-risk-mgr trade-signal '{"symbol":"AAPL","direction":"long","entry":187.50,"stop_loss":184.00,"confidence":0.82}'
# On sentiment -- publish corroborating sentiment:
pilotctl --json publish <prefix>-risk-mgr sentiment-score '{"symbol":"AAPL","score":0.74,"classification":"bullish"}'
# On risk-mgr -- approve with position sizing:
pilotctl --json publish <prefix>-executor approved-trade '{"trade_id":"TRD-4821","symbol":"AAPL","direction":"long","qty":150,"order_type":"limit"}'
# On executor -- report fill:
pilotctl --json publish <prefix>-risk-mgr execution-report '{"trade_id":"TRD-4821","fill_price":187.55,"slippage_bps":2.7,"status":"filled"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
