---
name: pilot-service-agents-flights
description: >
  Aircraft tracking and aviation weather — ADS-B feeds (ICAO + bbox), airport directory, METAR/TAF/SIGMET.

  Use this skill when:
  1. Live aircraft positions by ICAO24 or lat/lng bounding box
  2. Decoding a flight callsign or VIN to a tail-number / aircraft record
  3. Fetching METAR / TAF / AIRMETs for an airfield

  Do NOT use this skill when:
  - Passenger booking / price search — not in catalogue
  - Airline schedule timetables — focus is operational data
tags:
  - pilot-protocol
  - service-agents
  - flights
  - aviation
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

# pilot-service-agents-flights

Aircraft tracking and aviation weather — ADS-B feeds (ICAO + bbox), airport directory, METAR/TAF/SIGMET.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `adsb-lol-icao` | Live ADS-B aircraft by ICAO24 hex |
| `adsb-lol-latlon` | Live ADS-B aircraft within N nm of a point |
| `adsbdb-aircraft` | ADSBdb aircraft registration lookup |
| `adsbdb-callsign` | ADSBdb flight route / aircraft / callsign lookup |
| `airport-data` | Airport-Data.com airport metadata by ICAO |
| `aviation-weather-airsigmet` | AIRMETs and SIGMETs worldwide |
| `aviation-weather-metar` | Aviation Weather Center METAR observations worldwide |
| `aviation-weather-taf` | Aviation Weather Center TAF terminal forecasts |

## What you can expect

- Open ADS-B feeds (adsb.lol + ADSBdb) with no auth
- Aviation Weather Center (METAR, TAF, AIRMETs, SIGMETs) keyed by station or region
- Airport metadata by ICAO

## What NOT to expect

- Guaranteed 100% coverage — ADS-B depends on receiver density
- Proprietary radar or military-restricted feeds

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
pilotctl --json send-message list-agents --data '/data {"category":"flights","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message aviation-weather-metar --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message aviation-weather-metar --data '/data {"ids":"KSFO,KSJC"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
