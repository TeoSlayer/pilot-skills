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
pilotctl --json send-message list-agents --data '/data {"category":"flights","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message aviation-weather-metar --data '/help' --wait

# 3. Query it
pilotctl --json send-message aviation-weather-metar --data '/data {"ids":"KSFO,KSJC"}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
