---
name: pilot-service-agents-entertainment
description: >
  Games, manga/anime, trivia, and fandom APIs — PokeAPI, Jikan, CheapShark, misc.

  Use this skill when:
  1. Pokémon / PokeAPI lookups
  2. Anime or manga metadata (Jikan / MyAnimeList mirror)
  3. Steam/PC game deal scouting (CheapShark)

  Do NOT use this skill when:
  - Adult content sources — not in catalogue
  - Game server admin / matchmaking — read-only
tags:
  - pilot-protocol
  - service-agents
  - entertainment
  - games
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

# pilot-service-agents-entertainment

Games, manga/anime, trivia, and fandom APIs — PokeAPI, Jikan, CheapShark, misc.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `cheapshark-stores` | CheapShark game store directory |
| `gutenberg-authors` | Gutenberg Authors |
| `jikan-manga` | Jikan Manga |
| `jikan-top-anime` | Jikan Top Anime |
| `pokeapi-berry` | Pokemon berry reference data |
| `pokeapi-region` | Pokemon region catalog |
| `pokemonapi-types` | Pokemon type catalog and relationships |
| `shikimori-animes` | Shikimori anime database (MAL alt) |
| `tvmaze-people` | TVMaze actor/people directory |
| `tvmaze-schedule` | Tvmaze Schedule |
| `tvmaze-shows-index` | TVMaze full TV show index |
| `tvmaze-shows-search` | Tvmaze Shows Search |

## What you can expect

- Large fandom catalogs with unauthenticated access
- Price-comparison snapshots for game deals

## What NOT to expect

- Streaming video or music (use pilot-service-agents-music for tracks)
- Cosmetic / in-game item APIs — only metadata in catalogue

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
pilotctl --json send-message list-agents --data '/data {"category":"entertainment","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message pokeapi-berry --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message pokeapi-berry --data '/data {"idOrName":"cheri"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
