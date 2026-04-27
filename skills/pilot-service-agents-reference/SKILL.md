---
name: pilot-service-agents-reference
description: >
  Lightweight utility lookups — dictionaries, jokes, colors, currencies, random facts, D&D data, etc.

  Use this skill when:
  1. Defining a word, expanding an abbreviation, looking up a synonym or rhyme
  2. Fetching low-stakes factoids (cat fact, advice, random trivia, D&D reference)
  3. Currency codes and latest/historical FX rates (Frankfurter)

  Do NOT use this skill when:
  - Live market data or crypto prices (use pilot-service-agents-finance)
  - Detailed country profiles (use pilot-service-agents-data — e.g. `restcountries-all`)
  - Knowledge-graph entity lookups (use pilot-service-agents-knowledge)
tags:
  - pilot-protocol
  - service-agents
  - reference
  - lookup
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

# pilot-service-agents-reference

Lightweight utility lookups — dictionaries, jokes, colors, currencies, random facts, D&D data, etc.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `advice-slip` | Random advice slips — daily wisdom |
| `catfact-ninja` | Cat facts with pagination |
| `cheapshark-deals` | Live discounted Steam/PC game deals |
| `color-api` | Color information lookup (hex, RGB, HSL, names) |
| `dadjoke-search` | ICanHazDadJoke search |
| `datamuse` | Datamuse word tools - synonyms, rhymes, related terms |
| `dictionary-api` | Free Dictionary - English word definitions and pronunciation |
| `dnd5e-classes` | D&D 5e character class reference |
| `dnd5e-monsters` | D&D 5e monster stats reference |
| `dnd5e-spells` | D&D 5e spells, monsters, classes reference |
| `frankfurter-currencies` | ECB supported currencies |
| `frankfurter-historical` | Historical FX rates for a date |
| `frankfurter-latest` | ECB currency rates |
| `gcp-books` | Google Books volume search (1K/day free) |
| `gcp-fact-check` | Google Fact Check Tools claim verification |
| `joke-api-random` | Official Joke API random joke |
| `jokeapi-programming` | Programming and general jokes API |
| `makeup-products` | Makeup product search by brand/type |
| `mdn-search` | MDN docs search |
| `open-trivia` | Open Trivia DB — quiz questions across categories |
| `openstax-books` | Openstax Books |
| `random-user` | Random realistic user profile generator |
| `restcountries-name` | Country lookup by name |
| `swapi-people` | Star Wars universe data (people, planets, ships) |
| `timeapi-io` | timeapi.io - current time by timezone |
| `wikidata-wbgetentities` | Wikidata entities by id |
| `wttr-in` | wttr.in - weather forecasts for any location |
| `xkcd-latest` | XKCD latest comic metadata |

## What you can expect

- Many small, single-purpose wrappers — fast responses, no auth, no quota concerns
- English dictionary, Datamuse word tools, jokes/trivia/advice APIs
- ECB currency and historical FX (no authentication needed)

## What NOT to expect

- Deep analytical data — this is the grab-bag of small useful APIs
- Always-current pricing — market data lives in `finance`

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
pilotctl --json send-message list-agents --data '/data {"category":"reference","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message free-dictionary-en --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message free-dictionary-en --data '/data {"word":"serendipity"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
