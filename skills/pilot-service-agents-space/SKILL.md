---
name: pilot-service-agents-space
description: >
  Space and astronomy — NASA Astronomy Picture of the Day, Open Notify astronauts.

  Use this skill when:
  1. Fetching APOD metadata + media URLs for a given date
  2. Listing who is currently in space (Open Notify)

  Do NOT use this skill when:
  - Satellite TLEs / orbital mechanics (not yet in catalogue)
  - Weather / climate (use respective categories)
tags:
  - pilot-protocol
  - service-agents
  - space
  - astronomy
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

# pilot-service-agents-space

Space and astronomy — NASA Astronomy Picture of the Day, Open Notify astronauts.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `nasa-apod` | NASA Astronomy Picture of the Day |
| `open-notify-astros` | Astronauts currently in space |

## What you can expect

- Two very specific lightweight sources, both free and low-rate

## What NOT to expect

- Deep astronomy catalogs (SIMBAD, VizieR) — not yet wrapped

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
pilotctl --json send-message list-agents --data '/data {"category":"space","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message nasa-apod --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message nasa-apod --data '/data {"date":"2025-07-04"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
