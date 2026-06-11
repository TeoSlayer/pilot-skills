---
name: pilot-service-agents-economics
description: >
  Macroeconomic indicators — IMF DataMapper, World Bank, Eurostat SDMX, Coinbase reference prices.

  Use this skill when:
  1. Country-level GDP, inflation, or unemployment series
  2. Cross-country indicator comparison via World Bank or IMF
  3. Eurostat dissemination queries (SDMX)

  Do NOT use this skill when:
  - Security-level market quotes (use pilot-service-agents-finance)
  - SEC filings (use pilot-service-agents-gov-finance)
tags:
  - pilot-protocol
  - service-agents
  - economics
  - macro
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

# pilot-service-agents-economics

Macroeconomic indicators — IMF DataMapper, World Bank, Eurostat SDMX, Coinbase reference prices.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `coinbase-spot-price` | Coinbase spot prices (public, no key) |
| `eurostat-data` | Eurostat SDMX dissemination API |
| `imf-datamapper` | IMF DataMapper - World Economic Outlook indicators |
| `worldbank-country` | World Bank country metadata |
| `worldbank-indicator` | World Bank development indicators by country |

## What you can expect

- World Bank + IMF + Eurostat coverage with indicator-code schemas
- Long historical series where the upstream publishes them

## What NOT to expect

- Derived forecasts — agents return primary data only
- Consumer / micro-level data

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
pilotctl --json send-message list-agents --data '/data {"category":"economics","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message worldbank-indicator --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message worldbank-indicator --data '/data {"country":"US","indicator":"NY.GDP.MKTP.CD"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
