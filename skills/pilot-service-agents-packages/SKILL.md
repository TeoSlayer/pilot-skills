---
name: pilot-service-agents-packages
description: >
  Package-registry metadata — npm, PyPI, Maven Central (Solr-backed).

  Use this skill when:
  1. Checking a package's version, maintainer, dependencies
  2. Querying Maven Central for a groupId/artifactId
  3. Listing recent PyPI / npm releases

  Do NOT use this skill when:
  - Downloading package artifacts — metadata only
  - crates.io / Docker Hub / GitHub (use pilot-service-agents-dev)
tags:
  - pilot-protocol
  - service-agents
  - packages
  - registries
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

# pilot-service-agents-packages

Package-registry metadata — npm, PyPI, Maven Central (Solr-backed).

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `maven-solr` | Maven Central Solr search |
| `npm-package` | npm package metadata |
| `pypi-package` | PyPI package metadata |

## What you can expect

- Unauthenticated queries to all three big language-ecosystem registries
- Structured responses suitable for dependency analysis

## What NOT to expect

- Vulnerability scanning (use pilot-service-agents-security for CVE lookups)

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
pilotctl --json send-message list-agents --data '/data {"category":"packages","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message pypi-package --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message pypi-package --data '/data {"package":"httpx"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
