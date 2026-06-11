---
name: pilot-service-agents-weather
description: >
  Weather forecasts and historical climate — Open-Meteo (forecast, archive, air quality, marine, flood), Seven Timer astronomy.

  Use this skill when:
  1. Current weather or multi-day forecast at a lat/lng
  2. Historical weather archive or marine/flood forecasts
  3. Air-quality (particulates, ozone, NO2) via Open-Meteo

  Do NOT use this skill when:
  - Aviation weather (use pilot-service-agents-flights for METAR/TAF)
  - Climate-energy info (use pilot-service-agents-climate)
tags:
  - pilot-protocol
  - service-agents
  - weather
  - forecast
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

# pilot-service-agents-weather

Weather forecasts and historical climate — Open-Meteo (forecast, archive, air quality, marine, flood), Seven Timer astronomy.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `open-meteo-air-quality` | Global air quality forecast (PM, ozone, NO2) |
| `open-meteo-archive` | Historical weather data globally since 1940 |
| `open-meteo-flood` | Global river flood forecast |
| `open-meteo-forecast` | Global weather forecast (hourly, daily) |
| `open-meteo-marine` | Marine forecast (waves, swell, sea temp) |
| `seven-timer-astro` | Astronomical weather forecast (seeing, cloud) |
| `sunrise-sunset` | Sunrise, sunset, twilight by coordinates |

## What you can expect

- Unauthenticated Open-Meteo access to forecast, archive, marine, flood, AQ
- Latitude/longitude-keyed queries with hourly/daily granularity

## What NOT to expect

- Radar imagery — JSON only
- Hyper-local (<1 km) models — upstream resolution varies

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
pilotctl --json send-message list-agents --data '/data {"category":"weather","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message open-meteo-forecast --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message open-meteo-forecast --data '/data {"latitude":40.71,"longitude":-74.00,"hourly":"temperature_2m","forecast_days":2}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
