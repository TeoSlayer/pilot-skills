---
name: pilot-service-agents-news
description: >
  News feeds, forum aggregators, and current-events streams — Hacker News, dev.to, GDELT, Reddit, Stack Exchange, USGS hazards.

  Use this skill when:
  1. Pulling current tech news / top stories (HN top/new, Lobsters, dev.to)
  2. Searching discussion archives (HN Algolia, Stack Exchange)
  3. Monitoring real-time events — hurricanes, earthquakes, spaceflight news

  Do NOT use this skill when:
  - Mainstream press articles (not in catalogue — use an external news API)
  - Scholarly literature (use pilot-service-agents-academic)
  - Sports scores (use pilot-service-agents-sports)
tags:
  - pilot-protocol
  - service-agents
  - news
  - current-events
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

# pilot-service-agents-news

News feeds, forum aggregators, and current-events streams — Hacker News, dev.to, GDELT, Reddit, Stack Exchange, USGS hazards.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `dev-to-articles` | dev.to article feed / search |
| `gdelt-context-api` | GDELT Context 2.0 - global event context data |
| `hackernews-jobstories` | Hacker News — job postings feed |
| `hackernews-newstories` | Hacker News — newest stories |
| `hn-algolia-search` | HN Algolia search |
| `hn-item` | HN item by id |
| `hn-top` | HN top stories list |
| `lemmy-posts` | Lemmy Posts |
| `lobsters-hottest` | Lobsters Hottest |
| `mediawiki-featured` | Mediawiki Featured |
| `noaa-nhc-storms` | NOAA National Hurricane Center - active tropical storms |
| `openbrewerydb-breweries` | OpenBreweryDB - worldwide brewery directory |
| `openlibrary-trending` | Openlibrary Trending |
| `reddit-public-sub` | Reddit public subreddit feed (JSON) |
| `spaceflight-news-articles` | Spaceflight news aggregator (articles) |
| `spaceflight-news-blogs` | Spaceflight news aggregator (blogs) |
| `stackexchange-questions` | Stack Overflow questions |
| `usgs-earthquakes` | USGS real-time global earthquake feed |
| `wayback-available` | Wayback Machine snapshot lookup |

## What you can expect

- Low-latency feeds of developer/tech content
- Archive.org Wayback and GDELT global-events context
- Public subreddit and Lemmy-community feeds (no auth)

## What NOT to expect

- Paywalled or syndicated press content
- Full-text rich media — feeds return titles/URLs/snippets

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
pilotctl --json send-message list-agents --data '/data {"category":"news","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message hn-top --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message hn-top --data '/data {"limit":10}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
