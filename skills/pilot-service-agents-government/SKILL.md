---
name: pilot-service-agents-government
description: >
  Government and civic data — federal register, FBI wanted, elections info, national open-data portals.

  Use this skill when:
  1. Finding current US federal regulations or notices (Federal Register)
  2. Looking up civic info: elections, polling, representatives (Google Civic Info)
  3. Searching national open-data catalogs (data.gov.br, Canadian CKAN, etc.)

  Do NOT use this skill when:
  - Financial filings (use pilot-service-agents-gov-finance for SEC/BLS)
  - Tariff lookups (use pilot-service-agents-gov-finance — `hts-usitc-search`)
  - Health statistics (use pilot-service-agents-health for CDC/WHO)
tags:
  - pilot-protocol
  - service-agents
  - government
  - civic
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

# pilot-service-agents-government

Government and civic data — federal register, FBI wanted, elections info, national open-data portals.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `brazil-api-banks` | Brazilian banks directory |
| `brazil-api-cep` | Brazilian ZIP/CEP postal code lookup |
| `canadian-gov-datasets` | Canadian Gov Datasets |
| `fbi-wanted` | FBI wanted persons list |
| `federal-register` | US Federal Register documents |
| `gcp-civic-elections` | Google Civic Info election directory |
| `noaa-alerts-active` | NWS active US weather alerts (GeoJSON) |
| `nobel-prize-laureates` | Nobel Prize laureates across all fields |
| `singapore-psi-air` | Singapore PSI/air quality reading |
| `singapore-weather-24h` | Singapore 24-hour weather forecast |
| `uk-parliament-members` | UK Parliament members search |
| `uk-police-crimes` | UK street-level crime data |
| `us-census-population` | US Census ACS population data |
| `usaspending-agencies` | US federal spending by agency |
| `weather-gov-stations` | Weather Gov Stations |
| `world-bank-health` | World Bank health expenditure indicator |
| `worldbank-income-levels` | Worldbank Income Levels |
| `worldbank-lending-types` | Worldbank Lending Types |
| `worldbank-projects` | Worldbank Projects |
| `worldbank-regions` | Worldbank Regions |
| `worldbank-sources` | Worldbank Sources |
| `worldbank-topics` | Worldbank Topics |

## What you can expect

- US and international civic/regulatory sources — Federal Register, FBI Wanted, Brazilian CEP + banks, Canadian open-data
- Google Civic Information (elections, polling locations) — premium gcp-civic-elections
- Structured filter-based search; /help on each agent shows the fields

## What NOT to expect

- Political commentary or news (use `news` category)
- Worldwide coverage — each agent is country-specific

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
pilotctl --json send-message list-agents --data '/data {"category":"government","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message federal-register --data '/help' --wait

# 3. Query it
pilotctl --json send-message federal-register --data '/data {"term":"clean air act","per_page":5}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
