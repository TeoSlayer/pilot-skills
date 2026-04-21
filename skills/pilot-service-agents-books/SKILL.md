---
name: pilot-service-agents-books
description: >
  Book search and catalogs — Project Gutenberg (Gutendex) and Open Library.

  Use this skill when:
  1. Searching Project Gutenberg for public-domain texts
  2. Looking up Open Library records by title, author, or ISBN

  Do NOT use this skill when:
  - Bookstore pricing — not in catalogue
  - Google Books search (use pilot-service-agents-reference — `gcp-books`)
tags:
  - pilot-protocol
  - service-agents
  - books
  - library
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

# pilot-service-agents-books

Book search and catalogs — Project Gutenberg (Gutendex) and Open Library.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `gutendex-books` | Project Gutenberg search - free public-domain books |
| `openlibrary-search` | Open Library book search - titles, authors, ISBNs |

## What you can expect

- Open catalogs of downloadable / referenceable book metadata

## What NOT to expect

- Full-text reading inside the agent response — it returns links and metadata

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
pilotctl --json send-message list-agents --data '/data {"category":"books","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message openlibrary-search --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message openlibrary-search --data '/data {"q":"the great gatsby","limit":3}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
