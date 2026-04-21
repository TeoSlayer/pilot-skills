---
name: pilot-service-agents-sports
description: >
  Live sports scores, fixtures, and historical stats — MLB, NFL, NHL, NBA, Formula 1, cricket, and generic TheSportsDB.

  Use this skill when:
  1. Live/upcoming game scores and schedules
  2. Player, team, or league metadata across multiple sports
  3. Formula 1 season standings and race results

  Do NOT use this skill when:
  - Sports-betting odds — not in catalogue
  - Fantasy-league roster management (read-only agents)
tags:
  - pilot-protocol
  - service-agents
  - sports
  - live-scores
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

# pilot-service-agents-sports

Live sports scores, fixtures, and historical stats — MLB, NFL, NHL, NBA, Formula 1, cricket, and generic TheSportsDB.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `cricket-espn` | ESPN Cricket live scoreboard |
| `espn-nba-scoreboard` | ESPN NBA live scoreboard (unofficial) |
| `jolpica-f1-current` | Formula 1 current season data (Ergast mirror) |
| `mlb-api-live` | ESPN MLB live scoreboard |
| `nfl-api-live` | ESPN NFL live scoreboard |
| `nhl-api-live` | ESPN NHL live scoreboard |
| `nhl-teams` | Nhl Teams |
| `openf1-drivers` | Openf1 Drivers |
| `openfootball-leagues` | Open Football English Premier League match results |
| `openligadb-matches` | Bundesliga/Euro/WC match results |
| `rugby-espn-rwc` | ESPN Rugby international live scoreboard |
| `tennis-api` | ESPN ATP tennis live scoreboard |
| `thesportsdb-countries` | Thesportsdb Countries |
| `thesportsdb-events` | Sports event results by round |
| `thesportsdb-leagues` | All sports leagues worldwide |
| `thesportsdb-search` | Cross-league team/event search |
| `thesportsdb-seasons` | Thesportsdb Seasons |

## What you can expect

- ESPN-style scoreboard snapshots for major US leagues
- Ergast/Jolpica mirror for historical F1
- TheSportsDB cross-sport metadata

## What NOT to expect

- Real-time play-by-play streams — agents return snapshots only
- Private club or minor-league coverage

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
pilotctl --json send-message list-agents --data '/data {"category":"sports","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message espn-nba-scoreboard --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message espn-nba-scoreboard --data '/data {}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
