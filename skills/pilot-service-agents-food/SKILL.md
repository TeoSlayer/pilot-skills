---
name: pilot-service-agents-food
description: >
  Food, recipes, and nutrition — OpenFoodFacts, TheCocktailDB, TheMealDB, Fruityvice, Open Brewery DB.

  Use this skill when:
  1. Looking up a packaged food by barcode (OpenFoodFacts)
  2. Recipe search by name, cuisine, or ingredient (MealDB, CocktailDB)
  3. Breweries near a location (Open Brewery DB)

  Do NOT use this skill when:
  - Medical nutrition advice (use pilot-service-agents-health)
  - Calorie tracking — agents only return reference nutrition data
tags:
  - pilot-protocol
  - service-agents
  - food
  - recipes
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

# pilot-service-agents-food

Food, recipes, and nutrition — OpenFoodFacts, TheCocktailDB, TheMealDB, Fruityvice, Open Brewery DB.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `cocktaildb-filter` | Cocktaildb Filter |
| `cocktaildb-ingredient` | CocktailDB detailed ingredient lookup |
| `fruityvice-all` | Fruit nutrition data |
| `mealdb-categories` | Mealdb Categories |
| `openbrewerydb-search` | Openbrewerydb Search |
| `openfoodfacts-product` | Food product lookup by barcode (OpenFoodFacts) |
| `openfoodfacts-search` | Food product search (OpenFoodFacts) |
| `thecocktaildb-search` | Cocktail recipe search |
| `themealdb-filter-area` | MealDB recipes filtered by cuisine area |
| `themealdb-list-ingredients` | MealDB full ingredient catalog |
| `themealdb-random` | Random recipe from MealDB |
| `themealdb-search` | Recipe search by name |

## What you can expect

- Community-maintained product and recipe catalogs
- Ingredient metadata and structured nutrition facts where the upstream has them

## What NOT to expect

- Restaurant reservations or menus
- Real-time delivery / price data

## Commands (same pattern for every agent in the category)

```bash
# Read an agent's filter contract
pilotctl --json send-message <hostname> --data "/help" --wait

# Fetch structured data
pilotctl --json send-message <hostname> --data '/data {json filters}' --wait

# Natural-language summary (Gemini)
pilotctl --json send-message <hostname> --data '/summary {json filters}' --wait
```

## Response shape

With `--wait`, `send-message` blocks until the agent replies (up to 30 s by default) and prints one JSON document: the ACK fields (`{"ack":"ACK TEXT N bytes", "bytes":N, "target":"<address>", "type":"text"}`) plus `reply`, the agent's message. The agent's normalised envelope is the JSON string in `data.reply.data` (pilotctl v1.12.2 and older print two JSON documents instead: the send result, then the reply, whose `data.data` is the envelope). A non-zero exit means no reply arrived (the error JSON on stderr has a `code` such as `timeout`) — treat that as *no data*, never as a cue to read older messages from the inbox. A reply that lands after the wait can still be picked up by sender and time: `pilotctl --json inbox --from <hostname> --since 5m --latest`. The envelope:

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
pilotctl --json send-message list-agents --data '/data {"category":"food","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message themealdb-search --data '/help' --wait

# 3. Query it
pilotctl --json send-message themealdb-search --data '/data {"s":"arrabbiata"}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
