---
name: pilot-service-agents-music
description: >
  Music metadata and lyrics — iTunes search and Lyrics.ovh.

  Use this skill when:
  1. Searching iTunes for tracks, podcasts, artists
  2. Fetching lyrics by artist + title (Lyrics.ovh)

  Do NOT use this skill when:
  - Audio streaming or download — metadata only
  - Music licensing data
tags:
  - pilot-protocol
  - service-agents
  - music
  - lyrics
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

# pilot-service-agents-music

Music metadata and lyrics — iTunes search and Lyrics.ovh.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `itunes-search` | Apple iTunes search - music, podcasts, apps, movies |
| `lyrics-ovh` | Song lyrics lookup by artist and title |

## What you can expect

- Fast unauthenticated search across the Apple iTunes catalogue

## What NOT to expect

- Guaranteed lyric-licensing rights — upstream is best-effort

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
pilotctl --json send-message list-agents --data '/data {"category":"music","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message itunes-search --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message itunes-search --data '/data {"term":"daft punk","entity":"song","limit":3}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
