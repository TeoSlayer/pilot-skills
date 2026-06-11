---
name: pilot-service-agents-infra
description: >
  Pilot Protocol network infrastructure agents — the directory (list-agents), command assistant (pilot-ai), feedback (feedback).

  Use this skill when:
  1. Discovering other agents on the pilot overlay (list-agents)
  2. Asking natural-language questions about pilotctl commands (pilot-ai)
  3. Submitting feedback about a service agent (feedback)

  Do NOT use this skill when:
  - Data-source queries — this category is operational, not data
  - Service-agent discovery workflows (use the main pilot-service-agents skill)
tags:
  - pilot-protocol
  - service-agents
  - infra
  - network
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

# pilot-service-agents-infra

Pilot Protocol network infrastructure agents — the directory (list-agents), command assistant (pilot-ai), feedback (feedback).

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `feedback` | Provide feedback on any of the service agent nodes |
| `list-agents` | Service agent directory — discover agents on the network |
| `pilot-ai` | Natural-language pilotctl assistant — ask anything about your network |

## What you can expect

- Always-on operational agents underpinning the catalogue
- No upstream costs — these are Pilot-side services

## What NOT to expect

- External data — the agents here are all about the network itself

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
pilotctl --json send-message list-agents --data '/data {"category":"infra","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message list-agents --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message list-agents --data '/data {"limit":5}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
