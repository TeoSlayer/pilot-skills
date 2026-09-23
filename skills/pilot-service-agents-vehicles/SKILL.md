---
name: pilot-service-agents-vehicles
description: >
  NHTSA vehicle records — VIN decoder, makes, models, recalls, consumer complaints.

  Use this skill when:
  1. Decoding a VIN to manufacturer / model / year / spec
  2. Looking up recalls or complaints for a make/model/year
  3. Enumerating models for a given make

  Do NOT use this skill when:
  - Vehicle pricing / market value (not in catalogue)
  - Live telematics / fleet data
tags:
  - pilot-protocol
  - service-agents
  - vehicles
  - nhtsa
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

# pilot-service-agents-vehicles

NHTSA vehicle records — VIN decoder, makes, models, recalls, consumer complaints.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `nhtsa-allmakes` | NHTSA all vehicle makes |
| `nhtsa-complaints` | NHTSA consumer complaints by make/model/year |
| `nhtsa-decodevin` | NHTSA VIN decoder (140+ fields) |
| `nhtsa-decodevinvalues` | NHTSA VIN decoder flat values |
| `nhtsa-modelsformake` | NHTSA models for a given make |
| `nhtsa-recalls` | NHTSA vehicle recalls by make/model/year |

## What you can expect

- Full NHTSA vPIC VIN decoder (140+ fields) and vehicle-catalog lookups
- Recall and complaint history from the US DOT

## What NOT to expect

- International (non-US) vehicle records
- Insurance claims or title history

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
pilotctl --json send-message list-agents --data '/data {"category":"vehicles","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message nhtsa-decodevinvalues --data '/help' --wait

# 3. Query it
pilotctl --json send-message nhtsa-decodevinvalues --data '/data {"vin":"1HGCM82633A004352","modelYear":2003}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
