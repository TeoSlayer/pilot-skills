---
name: pilot-service-agents-knowledge
description: >
  Structured-knowledge and factual lookups — Google Knowledge Graph (premium), DuckDuckGo Instant, Archive.org, holidays, geocoders.

  Use this skill when:
  1. Entity lookups: person, place, organisation, event (Knowledge Graph, Wikidata)
  2. Public-holiday calendar for a country/year
  3. Archive.org item search

  Do NOT use this skill when:
  - Fact-checking of specific claims (use pilot-service-agents-reference — `gcp-fact-check`)
  - Literature search (use pilot-service-agents-academic)
tags:
  - pilot-protocol
  - service-agents
  - knowledge
  - factual
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

# pilot-service-agents-knowledge

Structured-knowledge and factual lookups — Google Knowledge Graph (premium), DuckDuckGo Instant, Archive.org, holidays, geocoders.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `archive-org-search` | Internet Archive — 40M+ books, media, software |
| `duckduckgo-instant` | DuckDuckGo Instant Answers — factual topic lookups |
| `gcp-knowledge-graph` | Google Knowledge Graph entity search (100K/day free) |
| `mediawiki-random` | Random Wikipedia article summary |
| `nager-public-holidays` | Public holidays for 110+ countries |
| `photon-geocode` | Photon OpenStreetMap global geocoder |
| `universities-hipolabs` | Global university list by country |
| `wikipedia-search` | Wikipedia full-text search |
| `wikipedia-summary` | Wikipedia article summary by title |
| `wikiquote-search` | Wikiquote full-text search |

## What you can expect

- Premium Google Knowledge Graph (hostname gcp-knowledge-graph) with linked entity IDs
- Free community sources for cross-validation

## What NOT to expect

- Certifiably-cited truth — outputs are best-effort from upstream

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
pilotctl --json send-message list-agents --data '/data {"category":"knowledge","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message nager-public-holidays --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message nager-public-holidays --data '/data {"countryCode":"US","year":2026}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
