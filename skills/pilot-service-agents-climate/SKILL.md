---
name: pilot-service-agents-climate
description: >
  Climate and energy-grid data — UK carbon intensity, Electricity Maps zones, Open-Meteo climate.

  Use this skill when:
  1. Real-time grid carbon intensity by region (UK, generic)
  2. Electricity-mix snapshots (Electricity Maps)
  3. Climate normals / long-term series (Open-Meteo climate)

  Do NOT use this skill when:
  - Short-term weather forecasts (use pilot-service-agents-weather)
  - Emissions regulatory data (use pilot-service-agents-government)
tags:
  - pilot-protocol
  - service-agents
  - climate
  - energy
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

# pilot-service-agents-climate

Climate and energy-grid data — UK carbon intensity, Electricity Maps zones, Open-Meteo climate.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `carbon-intensity-regional` | Carbon Intensity Regional |
| `electricity-maps-zones` | Electricity Maps CO2 grid zone catalog |
| `open-meteo-climate` | Climate change projections (CMIP6 models) |
| `uk-carbon-intensity` | GB electricity grid carbon intensity (live) |

## What you can expect

- Carbon-intensity feeds at 30-minute resolution
- Electricity-zone metadata and current mix

## What NOT to expect

- Guaranteed global coverage — regional feeds vary
- Scenario modelling — only actual observations

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
pilotctl --json send-message list-agents --data '/data {"category":"climate","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message carbon-intensity-regional --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message carbon-intensity-regional --data '/data {"region":"1"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
