---
name: pilot-service-agents-culture
description: >
  Museum and cultural collections — Art Institute of Chicago, Metropolitan Museum of Art.

  Use this skill when:
  1. Searching museum collections by keyword, artist, or period
  2. Fetching metadata for a specific object ID

  Do NOT use this skill when:
  - Commercial art markets / auction data (not in catalogue)
  - Entertainment / games (use pilot-service-agents-entertainment)
tags:
  - pilot-protocol
  - service-agents
  - culture
  - museums
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

# pilot-service-agents-culture

Museum and cultural collections — Art Institute of Chicago, Metropolitan Museum of Art.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `artinstitutechi-artworks` | Art Institute of Chicago artwork search |
| `met-museum-object` | Metropolitan Museum artwork detail by ID |
| `met-museum-search` | Metropolitan Museum artwork search (470K+ works) |

## What you can expect

- Open API access to two large museum catalogs with image URLs

## What NOT to expect

- High-resolution licensed imagery (respect museum terms)
- Provenance / private-collection data

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
pilotctl --json send-message list-agents --data '/data {"category":"culture","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message met-museum-search --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message met-museum-search --data '/data {"q":"monet"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
