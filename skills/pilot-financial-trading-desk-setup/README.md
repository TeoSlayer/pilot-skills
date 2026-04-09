# Financial Trading Desk Setup

A multi-agent trading desk that coordinates market analysis, sentiment scanning, risk management, and trade execution across four specialized agents. The analyst identifies trading opportunities from market data, the sentiment scanner provides supplementary signals from news and social media, the risk manager evaluates all proposed trades against portfolio constraints, and the executor handles order management and fill reporting.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### analyst (Market Analyst)
Monitors market data feeds, runs technical and fundamental analysis, identifies trading opportunities and publishes structured trade signals. Tracks price action, volume profiles, moving averages, and key support/resistance levels across multiple asset classes.

**Skills:** pilot-stream-data, pilot-metrics, pilot-cron, pilot-alert

### sentiment (Sentiment Scanner)
Scans news feeds, social media, and earnings reports for market-moving sentiment signals. Classifies content as bullish, bearish, or neutral with confidence scores. Detects unusual activity spikes that may precede large price movements.

**Skills:** pilot-stream-data, pilot-event-filter, pilot-archive

### risk-mgr (Risk Manager)
Evaluates proposed trades against portfolio exposure limits, position sizing rules, and maximum drawdown thresholds. Receives signals from both the analyst and sentiment scanner, correlates them, and either approves or rejects with detailed reasoning. Monitors real-time P&L.

**Skills:** pilot-event-filter, pilot-audit-log, pilot-alert

### executor (Trade Executor)
Receives approved trade signals from the risk manager, manages order timing and execution strategy (market, limit, TWAP), reports fills and slippage back to the risk manager for portfolio tracking. Interfaces with exchange APIs via webhooks.

**Skills:** pilot-task-router, pilot-receipt, pilot-webhook-bridge

## Data Flow

```
analyst   --> risk-mgr  : Trade signals with entry/exit levels and rationale (port 1002)
sentiment --> risk-mgr  : Sentiment scores with source attribution (port 1002)
risk-mgr  --> executor  : Approved trades with position size and risk parameters (port 1002)
executor  --> risk-mgr  : Execution reports with fill price and slippage (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On market analysis server
clawhub install pilot-stream-data pilot-metrics pilot-cron pilot-alert
pilotctl set-hostname <your-prefix>-analyst

# On sentiment scanning server
clawhub install pilot-stream-data pilot-event-filter pilot-archive
pilotctl set-hostname <your-prefix>-sentiment

# On risk management server
clawhub install pilot-event-filter pilot-audit-log pilot-alert
pilotctl set-hostname <your-prefix>-risk-mgr

# On execution server
clawhub install pilot-task-router pilot-receipt pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-executor
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# analyst <-> risk-mgr (trade signals)
# On analyst:
pilotctl handshake <your-prefix>-risk-mgr "setup: financial-trading-desk"
# On risk-mgr:
pilotctl handshake <your-prefix>-analyst "setup: financial-trading-desk"

# sentiment <-> risk-mgr (sentiment scores)
# On sentiment:
pilotctl handshake <your-prefix>-risk-mgr "setup: financial-trading-desk"
# On risk-mgr:
pilotctl handshake <your-prefix>-sentiment "setup: financial-trading-desk"

# risk-mgr <-> executor (approved trades and execution reports)
# On risk-mgr:
pilotctl handshake <your-prefix>-executor "setup: financial-trading-desk"
# On executor:
pilotctl handshake <your-prefix>-risk-mgr "setup: financial-trading-desk"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-analyst -- publish a trade signal:
pilotctl publish <your-prefix>-risk-mgr trade-signal '{"symbol":"AAPL","direction":"long","entry":187.50,"stop_loss":184.00,"take_profit":195.00,"timeframe":"4h","confidence":0.82,"rationale":"Golden cross on 50/200 MA with volume confirmation"}'

# On <your-prefix>-sentiment -- publish a sentiment score:
pilotctl publish <your-prefix>-risk-mgr sentiment-score '{"symbol":"AAPL","score":0.74,"classification":"bullish","sources":["earnings_beat","analyst_upgrade","insider_buying"],"timestamp":"2026-04-09T14:30:00Z"}'

# On <your-prefix>-risk-mgr -- approve and size the trade:
pilotctl publish <your-prefix>-executor approved-trade '{"trade_id":"TRD-4821","symbol":"AAPL","direction":"long","qty":150,"entry":187.50,"stop_loss":184.00,"order_type":"limit","max_slippage_bps":15}'

# On <your-prefix>-executor -- report execution:
pilotctl publish <your-prefix>-risk-mgr execution-report '{"trade_id":"TRD-4821","symbol":"AAPL","status":"filled","fill_price":187.55,"qty":150,"slippage_bps":2.7,"exchange":"NASDAQ","timestamp":"2026-04-09T14:31:12Z"}'
```
