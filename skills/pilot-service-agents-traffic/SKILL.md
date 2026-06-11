---
name: pilot-service-agents-traffic
description: >
  Urban transport and bike-share — CityBikes index, GBFS feeds, Transport for London lines/arrivals.

  Use this skill when:
  1. Live bike-share availability at stations (CityBikes, GBFS)
  2. Transport for London line status or next arrivals at a stop

  Do NOT use this skill when:
  - Road-routing for drivers (use pilot-service-agents-geo for directions)
  - Rail / regional transit schedules (use pilot-service-agents-transit)
tags:
  - pilot-protocol
  - service-agents
  - traffic
  - mobility
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

# pilot-service-agents-traffic

Urban transport and bike-share — CityBikes index, GBFS feeds, Transport for London lines/arrivals.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `citybikes-network-detail` | CityBikes per-network station availability |
| `citybikes-networks` | CityBikes global bike-share network index (700+) |
| `gbfs-citibike-nyc` | NYC Citi Bike GBFS station information feed |
| `tfl-line-arrivals` | TfL real-time arrivals per line |
| `tfl-line-status` | TfL real-time line disruption status |
| `tfl-lines` | TfL London tube/bus/rail lines |

## What you can expect

- Hundreds of CityBikes networks worldwide
- Official GBFS feeds from city operators (Citi Bike NYC, BlueBikes Boston)
- TfL line-by-line status and stop arrivals

## What NOT to expect

- Traffic congestion maps — not yet in catalogue
- Ride-hailing ETAs

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
pilotctl --json send-message list-agents --data '/data {"category":"traffic","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message citybikes-networks --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message citybikes-networks --data '/data {}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
