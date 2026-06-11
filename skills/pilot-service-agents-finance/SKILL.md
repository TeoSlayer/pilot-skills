---
name: pilot-service-agents-finance
description: >
  Public market data — crypto spot prices, FX rates, order books, and macro indicators.

  Use this skill when:
  1. Looking up current crypto spot prices (Coinbase, Binance, Bitstamp, CoinGecko, CoinLore)
  2. Getting FX rates or currency conversions (exchangerate.host, Frankfurter)
  3. Blockchain-ticker style market snapshots

  Do NOT use this skill when:
  - SEC company filings (use pilot-service-agents-gov-finance — `sec-company-facts`)
  - Macroeconomic indicators (use pilot-service-agents-economics)
  - Personal brokerage/portfolio data — these are public endpoints only
tags:
  - pilot-protocol
  - service-agents
  - finance
  - markets
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill, pilotctl binary on PATH, a running daemon
  registered with the backbone (Network 0 — joined automatically at registration), and the `list-agents` directory agent
  reachable on the overlay.
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# pilot-service-agents-finance

Public market data — crypto spot prices, FX rates, order books, and macro indicators.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `bea-gdp-data` | Bea Gdp Data |
| `binance-us-ticker` | Binance.US 24h trading pair tickers |
| `bitstamp-ticker` | Bitstamp BTC/USD real-time ticker |
| `bitstamp-transactions` | Live Bitcoin trade ticks from Bitstamp |
| `blockchain-ticker` | Bitcoin global prices by currency |
| `coingecko-markets-simple` | CoinGecko coins/markets - crypto prices, volume, market cap |
| `coinlore-global` | Global crypto market stats (cap, volume, BTC dominance) |
| `coinlore-tickers` | Top cryptocurrencies with price/volume/change |
| `coinpaprika-coins` | Cryptocurrency list and market data |
| `currency-api-latest` | 150+ currency exchange rates (no rate limit) |
| `ecb-exchange-rates` | ECB official Euro exchange rates |
| `ecb-stats-exr` | Ecb Stats Exr |
| `exchangerate-api-v6` | 150+ currency exchange rates (no rate limit) |
| `exchangerate-host` | Exchangerate.host - live FX rates, currency conversion |
| `fed-treasury-debt` | US national debt to the penny |
| `kraken-assetpairs` | Kraken tradable asset pairs with leverage/limits |
| `sec-edgar-full-text` | Sec Edgar Full Text |
| `worldbank-gdp-data` | Worldbank Gdp Data |

## What you can expect

- Unauthenticated spot/market feeds from multiple exchanges for cross-checking
- Free FX and historical rate lookups
- Market-cap, volume, order-book snapshots

## What NOT to expect

- Trade execution — read-only data only
- Deep historical tick data — upstream APIs limit lookback

## Commands (same pattern for every agent in the category)

```bash
# Read an agent's filter contract
pilotctl --json send-message <hostname> --data "/help"
pilotctl --json inbox

# Fetch structured data
pilotctl --json send-message <hostname> --data '/data {json filters}'
pilotctl --json inbox

# Natural-language summary (Gemini)
pilotctl --json send-message <hostname> --data '/summary {json filters}'
pilotctl --json inbox
```

## Response shape

`send-message` returns an ACK envelope immediately (`{"ack":"ACK TEXT N bytes", "bytes":N, "target":"<address>", "type":"text"}`). The **actual agent response** arrives a few seconds later and is read with `pilotctl --json inbox`. Each inbox entry carries the agent's normalised envelope in its `data` field:

```json
{
  "source": "<hostname>",
  "items":  [...],
  "count":  <int>,
  "total":  <int|null>,
  "page":   <int|null>,
  "next":   <cursor|null>,
  "truncated": <bool>,
  "upstream_url": "<resolved upstream URL>"
}
```

`/help` returns plain text. `/summary` returns a Gemini-generated prose string. Free-text queries also return Gemini prose.

## Workflow Example

```bash
# 1. Fresh discovery — the catalogue grows, never hard-code
pilotctl --json send-message list-agents --data '/data {"category":"finance","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message coingecko-markets-simple --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message coingecko-markets-simple --data '/data {"vs_currency":"usd","per_page":5}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
