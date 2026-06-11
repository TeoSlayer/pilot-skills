---
name: pilot-service-agents-geo
description: >
  Geographic and geolocation APIs — Google Maps suite (premium) plus open geocoders and IP-to-location lookups.

  Use this skill when:
  1. Converting addresses ↔ coordinates, or coordinates ↔ place names
  2. Computing directions, travel time, elevation, timezone, or air-quality at a point
  3. Finding places by text (Places New) or validating postal addresses

  Do NOT use this skill when:
  - Flight tracking (use pilot-service-agents-flights)
  - Public-transit schedules (use pilot-service-agents-transit)
  - Weather forecasts (use pilot-service-agents-weather)
tags:
  - pilot-protocol
  - service-agents
  - geo
  - maps
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

# pilot-service-agents-geo

Geographic and geolocation APIs — Google Maps suite (premium) plus open geocoders and IP-to-location lookups.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `country-from-ip` | Country detection from IP address |
| `elevation-open-meteo` | Elevation Open Meteo |
| `gcp-maps-address-validation` | Google Maps Address Validation (premium) |
| `gcp-maps-air-quality` | Google Maps Air Quality — current conditions (premium) |
| `gcp-maps-directions` | Google Maps Directions — driving/walking routes (premium) |
| `gcp-maps-distance-matrix` | Google Maps Distance Matrix — travel times (premium) |
| `gcp-maps-elevation` | Google Maps Elevation — elevation for coordinates (premium) |
| `gcp-maps-geocoding` | Google Maps Geocoding — address/coords (premium) |
| `gcp-maps-geolocation` | Google Geolocation — locate from WiFi/cell/IP (premium) |
| `gcp-maps-places-new` | Google Maps Places (New) — text place search (premium) |
| `gcp-maps-pollen` | Google Maps Pollen — forecast by coord (premium) |
| `gcp-maps-roads` | Google Maps Roads — snap GPS to roads (premium) |
| `gcp-maps-routes` | Google Maps Routes — traffic-aware routing v2 (premium) |
| `gcp-maps-solar` | Google Maps Solar — roof solar potential (premium) |
| `gcp-maps-timezone` | Google Maps Time Zone — tz from coords (premium) |
| `ip-api` | ip-api.com - IP geolocation, ISP, country, region |
| `nominatim-reverse` | OpenStreetMap reverse geocoder |
| `nominatim-search` | OpenStreetMap forward geocoder |
| `open-meteo-geocoding` | City name to coordinates geocoder (global) |
| `opensky-bbox` | Live aircraft states in a bounding box |
| `opentopodata-srtm` | Opentopodata Srtm |
| `osrm-route` | Open Source Routing Machine — driving directions |
| `overpass-api` | Overpass Api |
| `photon-reverse` | Photon Reverse |
| `rest-countries-currency` | Countries using a specific currency code |
| `rest-countries-region` | Countries by region (Europe/Asia/etc) |
| `restcountries-region` | Restcountries Region |
| `uk-postcodes` | UK postcode geolocation + admin lookup |
| `viacep-brazil` | Brazilian address lookup by CEP code |
| `zippopotam-city` | City info by country+zip (Zippopotam.us) |

## What you can expect

- Google Maps Platform coverage — geocoding, directions, distance matrix, elevation, timezone, roads, places, routes, address validation, geolocation, solar, air-quality, pollen
- All Google Maps agents are **premium** (hostname prefix `gcp-maps-*`) — paid upstream, higher accuracy and SLA
- Open alternatives for basic lookups (IP-to-country, open-elevation)

## What NOT to expect

- Free tier for Google services — pricing is metered upstream
- Real-time traffic fleet management (not in catalogue yet)
- Raw map tile imagery — the agents serve JSON envelopes, not PNGs

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
pilotctl --json send-message list-agents --data '/data {"category":"geo","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message gcp-maps-geocoding --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message gcp-maps-geocoding --data '/data {"address":"1600 Amphitheatre Pkwy Mountain View CA"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
