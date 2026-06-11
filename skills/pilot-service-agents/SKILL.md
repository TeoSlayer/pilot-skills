---
name: pilot-service-agents
description: >
  Discover and query the pilot-service-agents catalogue — ~370 always-on data
  agents reachable over Pilot Protocol that wrap real-world APIs (Google Maps,
  OpenAlex, NHTSA, USGS, CoinGecko, NASA, aviation weather, and many more) so
  callers don't need their own API keys, rate limits, or HTTP plumbing.

  Use this skill when:
  1. You need to answer a question that depends on up-to-date external data
     (geography, finance, aviation, science, health, academic literature, etc.)
     and do not want to hit the upstream APIs yourself.
  2. You want to discover which agents exist for a topic before invoking one.
  3. You want structured, paginated, filter-driven access to an upstream API
     without touching its SDK or auth.

  Do NOT use this skill when:
  - You want agent-to-agent chat (use pilot-chat instead).
  - You are looking for swarm/task coordination (use pilot-task-router instead).
  - You need to run your own data source — these agents are consumer-side only.
tags:
  - pilot-protocol
  - service-agents
  - data-sources
  - discovery
  - data-exchange
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start) and joined to
  the backbone (Network 0 — every daemon joins automatically at registration), which is where the catalogue lives.
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

# pilot-service-agents

Every service agent on Pilot Protocol exposes the **same four-command interface**
over the overlay, so once you understand one you understand them all. The
catalogue itself is served by a directory agent called `list-agents` — always
start there.

## The flow: discover → pick → invoke → read inbox

```
pilotctl send-message list-agents --data "/data {filters}"   (find agents)
pilotctl send-message <hostname>   --data "/help"            (read contract)
pilotctl send-message <hostname>   --data "/data {filters}"  (fetch data)
pilotctl inbox                                               (read response)
```

The send-message call returns an ACK immediately; the **actual response comes
back as an inbox message** a few seconds later from the agent you called.

## Discovering agents via list-agents

`list-agents` is the directory. Talk to it like any other agent.

### List all commands it supports
```bash
pilotctl --json send-message list-agents --data "/help"
pilotctl --json inbox
```

### Filter the catalogue
```bash
pilotctl --json send-message list-agents --data '/data {"category":"academic","limit":20}'
pilotctl --json inbox
```

Supported filter fields on `list-agents` `/data`:

| field | type | meaning |
|---|---|---|
| `category` | string | academic, geo, finance, news, health, science, security, … |
| `tier` | string | `free` (no per-request cost) or `premium` (paid, higher quality, e.g. Google Cloud) |
| `search` | string | substring match on hostname + category + description |
| `hostname` | string | exact hostname match |
| `limit` | int | max items (default 50, max 500) |

The response envelope contains `items`, `count`, `total`, `groups` (counts per
category), and `tiers.free` / `tiers.premium` buckets with their disclaimers.

### Gemini summary of matches
```bash
pilotctl --json send-message list-agents --data '/summary {"category":"flights"}'
pilotctl --json inbox
```

### Free-text question over the catalogue
```bash
pilotctl --json send-message list-agents --data 'which agent gives me Formula 1 race results?'
pilotctl --json inbox
```

## Talking to a specific service agent

Once you have a hostname, the **same four commands** work on every agent:

| message | what it does |
|---|---|
| `/help` | prints the filter schema + pagination + example call |
| `/data {json}` | fetch real data, returns a normalised envelope |
| `/summary {json}` | same fetch, piped through Gemini for prose |
| `<any free text>` | Gemini picks filters and fetches |

Filter shape for `/data` is agent-specific. Always read `/help` first — it lists
every filter with type, required flag, default, and description. Premium agents
(hostname prefix `gcp-`) announce themselves with a `[PREMIUM]` tag in `/help`.

### Canonical response envelope
Every `/data` response has this shape:

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

## Pagination

If an agent's `/help` shows `Pagination: page|offset|cursor`, pass the knob in
your filter JSON. The knobs the agent recognises are in the same `/help`
output. Omit pagination and you get the upstream's default page.

## Workflow Example

Answer "what aircraft are currently over Manhattan?" with zero upfront API
knowledge:

```bash
# 1. Find the right category
pilotctl --json send-message list-agents --data '/data {"category":"flights","limit":5}'
sleep 5
pilotctl --json inbox   # pick e.g. adsb-lol-latlon

# 2. Read its filter contract
pilotctl --json send-message adsb-lol-latlon --data '/help'
sleep 5
pilotctl --json inbox

# 3. Query with the filters you just learned
pilotctl --json send-message adsb-lol-latlon \
  --data '/data {"lat":40.78,"lon":-73.97,"radius":8}'
sleep 5
pilotctl --json inbox
```

## What to expect across the catalogue

The catalogue grows; treat every hostname list as a snapshot. To stay current,
always start with `list-agents /data` — never hard-code a list.

- **Free agents** — community API wrappers. Best for volume, exploration,
  unauthenticated lookups. Rate-limited on the upstream's side.
- **Premium agents** — `gcp-*` hostnames, backed by Google Cloud credits
  managed centrally. Higher accuracy, SLA-grade freshness, real cost per call.
- **Every agent caches upstream responses** for ~60s and serves stale data on
  upstream errors (`"cached": true, "cache_age_seconds": N` fields appear in
  the envelope when that happens).
- **Authentication is handled agent-side.** You never hold an API key.

## Related skills (per category)

There is a dedicated `pilot-service-agents-<category>` skill for each category
in the catalogue — read one of those once you know which kind of data you
need. Discover the list with:

```bash
pilotctl --json send-message list-agents --data '/data {}'
```

Then look for the matching `pilot-service-agents-*` skill.

## Dependencies

Requires pilot-protocol core skill, a running `pilotctl daemon` registered with the
backbone (Network 0 — every daemon joins it automatically at registration),
and the `list-agents` directory agent reachable on the overlay.
