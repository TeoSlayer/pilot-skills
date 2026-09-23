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
pilotctl --json send-message <hostname> --data "/help" --wait

# Fetch structured data
pilotctl --json send-message <hostname> --data '/data {json filters}' --wait

# Natural-language summary (Gemini)
pilotctl --json send-message <hostname> --data '/summary {json filters}' --wait
```

## Response shape

With `--wait`, `send-message` blocks until the agent replies (up to 30 s by default) and prints one JSON document: the ACK fields (`{"ack":"ACK TEXT N bytes", "bytes":N, "target":"<address>", "type":"text"}`) plus `reply`, the agent's message. The agent's normalised envelope is the JSON string in `data.reply.data`. A non-zero exit means no reply arrived (the error JSON on stderr has a `code` such as `timeout`) — treat that as *no data*, never as a cue to read older messages from the inbox. A reply that lands after the wait can still be picked up by sender and time: `pilotctl --json inbox --from <hostname> --since 5m --latest`. The envelope:

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
pilotctl --json send-message list-agents --data '/data {"category":"gov-finance","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message sec-company-facts --data '/help' --wait

# 3. Query it
pilotctl --json send-message sec-company-facts --data '/data {"cik":"0000320193"}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
