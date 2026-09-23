---
name: pilot-service-agents-dev
description: >
  Developer-platform metadata — GitHub, Docker Hub, crates.io, and other ecosystem registries.

  Use this skill when:
  1. Resolving a GitHub repo or fetching its stats / events
  2. Crate / container image / language-package metadata
  3. Searching popular repos, trending projects, public events

  Do NOT use this skill when:
  - Running package installs (read-only metadata)
  - Private repo access — these wrap public APIs
  - Npm/PyPI/Maven registries (use pilot-service-agents-packages)
tags:
  - pilot-protocol
  - service-agents
  - dev
  - developer-tools
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

# pilot-service-agents-dev

Developer-platform metadata — GitHub, Docker Hub, crates.io, and other ecosystem registries.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `crates-io-crate` | Crates Io Crate |
| `crates-io-recent` | Crates Io Recent |
| `docker-hub-search` | Docker Hub Search |
| `github-events-public` | Github Events Public |
| `github-public` | GitHub public repository metadata (unauth'd) |
| `github-search-repos` | GitHub repository search by language/stars/topic |
| `github-trending-repos` | Github Trending Repos |
| `gitlab-projects-search` | Gitlab Projects Search |
| `hex-pm-search` | Hex.pm Elixir/Erlang package search |
| `homebrew-formulae` | Homebrew Formulae |
| `jsdelivr-npm-stats` | Jsdelivr Npm Stats |
| `jsdelivr-stats` | jsDelivr CDN package download statistics |
| `npm-search` | Npm Search |
| `nuget-search` | Nuget Search |
| `packagist-search` | Packagist PHP/Composer package search |
| `packagist-stats` | Packagist Stats |
| `pub-dev-search` | Pub.dev Flutter/Dart package search |
| `rubygems-search` | RubyGems gem search |

## What you can expect

- GitHub public search + events + repo info without auth
- crates.io recent releases and specific crate lookup
- Docker Hub image search

## What NOT to expect

- Anything requiring OAuth or bearer tokens — authenticated data is out of scope
- Write operations

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

With `--wait`, `send-message` blocks until the agent replies (up to 30 s by default) and prints one JSON document: the ACK fields (`{"ack":"ACK TEXT N bytes", "bytes":N, "target":"<address>", "type":"text"}`) plus `reply`, the agent's message. The agent's normalised envelope is the JSON string in `data.reply.data`. A non-zero exit means no reply arrived (the error JSON on stderr has a `code` such as `timeout`) — treat that as *no data*, never as a cue to read older messages from the inbox. A reply that lands after the wait can still be picked up by sender and time: `pilotctl --json inbox --from <hostname> --since 5m --latest`. The envelope:

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
pilotctl --json send-message list-agents --data '/data {"category":"dev","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message github-search-repos --data '/help' --wait

# 3. Query it
pilotctl --json send-message github-search-repos --data '/data {"q":"language:rust stars:>10000","per_page":5}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
