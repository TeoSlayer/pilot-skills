---
name: pilot-service-agents-transit
description: >
  Public-transit schedules and live data — Amtrak, BART, Deutsche Bahn, Swiss SBB, BC Ferries, BVG Berlin, and more.

  Use this skill when:
  1. Live train / ferry / bus departures at a specific stop or station
  2. Planning a multi-modal journey between two stops (e.g. Swiss SBB, DB)
  3. Station directory lookups (Amtrak, Entur geocoder)

  Do NOT use this skill when:
  - City bike-share (use pilot-service-agents-traffic)
  - Aircraft / flight information (use pilot-service-agents-flights)
  - Road-routing for cars (use pilot-service-agents-geo)
tags:
  - pilot-protocol
  - service-agents
  - transit
  - public-transport
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

# pilot-service-agents-transit

Public-transit schedules and live data — Amtrak, BART, Deutsche Bahn, Swiss SBB, BC Ferries, BVG Berlin, and more.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `amtrak-stations` | Amtrak train schedules by station (unofficial) |
| `bart-etd` | Bart Etd |
| `bcferries-capacity` | BC Ferries sailing capacity & schedule |
| `bvg-berlin-departures` | Berlin BVG live departures by stop |
| `entur-geocoder` | Norway national transit geocoder |
| `gbfs-bluebikes-boston` | Gbfs Bluebikes Boston |
| `gbfs-capitalbikeshare-dc` | Gbfs Capitalbikeshare Dc |
| `gbfs-divvy-chicago` | Gbfs Divvy Chicago |
| `gbfs-lyft-bayarea` | Gbfs Lyft Bayarea |
| `gbfs-toronto-bikeshare` | Gbfs Toronto Bikeshare |
| `irail-liveboard` | Belgian SNCB live rail departures |
| `mbta-routes` | Mbta Routes |
| `mbta-stops` | Mbta Stops |
| `mta-nyc-subway-stations` | NYC MTA subway station metadata |
| `swiss-transport-connections` | Swiss public transport connection search |
| `tfl-stoppoint-meta` | TfL stop point category metadata |
| `transport-rest-journeys` | Deutsche Bahn multi-modal journey planner |
| `transport-rest-stations` | Deutsche Bahn station search |

## What you can expect

- Multi-country rail and transit: US (Amtrak, BART), Germany (DB, BVG), Switzerland, Belgium (iRail), Norway (Entur)
- Real-time departure boards and delay data where the upstream exposes it

## What NOT to expect

- Rideshare / taxi availability
- Fare-payment or ticketing flows — read-only

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
pilotctl --json send-message list-agents --data '/data {"category":"transit","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message bart-etd --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message bart-etd --data '/data {"orig":"POWL"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
