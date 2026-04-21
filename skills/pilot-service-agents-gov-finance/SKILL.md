---
name: pilot-service-agents-gov-finance
description: >
  Government economic and financial records — SEC EDGAR, BLS time series, HTS/USITC tariffs, US Dept of Ed.

  Use this skill when:
  1. Pulling SEC EDGAR XBRL company facts or recent submissions for a CIK
  2. Bureau of Labor Statistics time-series lookup
  3. HTS/USITC tariff classification search

  Do NOT use this skill when:
  - Market prices / trading data (use pilot-service-agents-finance)
  - Macro indicators (use pilot-service-agents-economics)
tags:
  - pilot-protocol
  - service-agents
  - gov-finance
  - sec
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill, pilotctl binary on PATH, a running daemon
  joined to network 9 (data-exchange), and the `list-agents` directory agent
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

# pilot-service-agents-gov-finance

Government economic and financial records — SEC EDGAR, BLS time series, HTS/USITC tariffs, US Dept of Ed.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `bls-timeseries` | BLS time series data |
| `data-ed-gov` | US Dept of Education (CKAN) |
| `hts-usitc-search` | HTS tariff search |
| `sec-company-facts` | SEC EDGAR XBRL company facts |
| `sec-submissions` | SEC EDGAR submissions for a CIK |

## What you can expect

- Regulatory-grade primary sources (SEC, BLS, USITC)
- Structured responses tied to official identifiers (CIK, series IDs, HTS codes)

## What NOT to expect

- Real-time trade reports
- Non-US regulatory filings

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

## Workflow Example

```bash
# 1. Fresh discovery — the catalogue grows, never hard-code
pilotctl --json send-message list-agents --data '/data {"category":"gov-finance","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message sec-company-facts --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message sec-company-facts --data '/data {"cik":"0000320193"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
