---
name: pilot-service-agents-science
description: >
  Primary-source scientific and research APIs — earthquakes, molecules, space weather, particle physics, volcanoes.

  Use this skill when:
  1. Looking up scientific observations (earthquakes, volcanic activity, space events)
  2. Searching molecule / drug / chemistry databases (ChEMBL, PubChem)
  3. Accessing dataset catalogs from research repositories (Dataverse, CERN)

  Do NOT use this skill when:
  - General reference lookups (use pilot-service-agents-reference)
  - Scholarly paper search (use pilot-service-agents-academic)
  - Live weather forecasts (use pilot-service-agents-weather)
tags:
  - pilot-protocol
  - service-agents
  - science
  - research
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

# pilot-service-agents-science

Primary-source scientific and research APIs — earthquakes, molecules, space weather, particle physics, volcanoes.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `cern-opendata` | CERN Open Data Portal — particle physics datasets |
| `chembl-assay-search` | Chembl Assay Search |
| `chembl-molecule` | ChEMBL molecule/drug compound data (EBI) |
| `chembl-target-search` | Chembl Target Search |
| `dataverse-search` | Harvard Dataverse research dataset search |
| `ebi-chembl-drug` | Ebi Chembl Drug |
| `ebi-proteins` | Ebi Proteins |
| `exoplanet-archive` | Exoplanet Archive |
| `figshare-articles` | Figshare open research articles and datasets |
| `gbif-datasets` | Gbif Datasets |
| `gbif-occurrence` | Gbif Occurrence |
| `gbif-species` | Global Biodiversity species search |
| `inaturalist-taxa` | Inaturalist Taxa |
| `inspire-literature` | High-energy physics research papers |
| `isro-spacecraft` | ISRO Indian space agency spacecraft catalog |
| `launchlibrary2-previous` | Historical rocket launch data |
| `launchlibrary2-upcoming` | Upcoming rocket launches worldwide |
| `nasa-eonet-events` | NASA EONET - global natural events |
| `nasa-techport` | NASA TechPort — active technology projects |
| `newton-math` | Symbolic math solver (factor, derive, etc.) |
| `opentopodata-etopo1` | OpenTopoData ETOPO1 - global elevation lookup |
| `orcid-search` | ORCID researcher identifier search |
| `osf-preprints` | OSF preprints (cross-discipline open papers) |
| `simbad-tap` | Simbad Tap |
| `spacex-upcoming` | SpaceX upcoming launches |
| `tle-satellites` | TLE satellite orbital elements database |
| `uniprot-search` | Uniprot Search |
| `usgs-volcanic-activity` | Usgs Volcanic Activity |
| `usgs-water` | USGS real-time water levels and discharge |
| `waqi-feed` | WAQI global Air Quality Index (demo token) |
| `wikidata-query` | Wikidata entity lookup by Q-id |
| `zenodo-records` | Zenodo scientific data/preprint records |

## What you can expect

- Curated research data — PubChem compounds, ChEMBL assays/targets, USGS seismic and hydrology feeds
- Near-real-time natural-event streams (NASA EONET, USGS earthquakes)
- Open-data catalog search (Dataverse, CERN, Zenodo)

## What NOT to expect

- Literature or citations — those live under `academic`
- Medical clinical guidance — those live under `health`
- Raw binary datasets — agents return metadata/summary JSON, not downloads

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
pilotctl --json send-message list-agents --data '/data {"category":"science","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message usgs-earthquakes --data '/help' --wait

# 3. Query it
pilotctl --json send-message usgs-earthquakes --data '/data {"starttime":"2026-04-19","minmagnitude":5}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
