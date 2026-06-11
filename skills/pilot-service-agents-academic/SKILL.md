---
name: pilot-service-agents-academic
description: >
  Scholarly literature and bibliographic databases — OpenAlex, Crossref, Europe PMC, PubMed, DOAJ, DBLP, Semantic Scholar.

  Use this skill when:
  1. Searching peer-reviewed works by author, title, keyword, or DOI
  2. Walking the citation / funder / institution graph (OpenAlex)
  3. Looking up a DBLP author page or a ROR organisation record

  Do NOT use this skill when:
  - Full-text article download — agents return metadata only
  - Clinical guideline search (use pilot-service-agents-health — clinicaltrials, PubMed eSearch is in `academic`)
  - Book catalog search (use pilot-service-agents-books)
tags:
  - pilot-protocol
  - service-agents
  - academic
  - scholarly
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

# pilot-service-agents-academic

Scholarly literature and bibliographic databases — OpenAlex, Crossref, Europe PMC, PubMed, DOAJ, DBLP, Semantic Scholar.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `crossref-funders` | Crossref Funders |
| `crossref-works` | Crossref works search |
| `dblp-author-search` | Dblp Author Search |
| `dblp-publ-search` | Dblp Publ Search |
| `doaj-articles` | Open access article search |
| `europepmc-search` | Europe PMC search |
| `ncbi-esearch` | PubMed search (eutils) |
| `openalex-authors` | OpenAlex author search |
| `openalex-concepts` | Openalex Concepts |
| `openalex-funders` | Openalex Funders |
| `openalex-institutions` | Openalex Institutions |
| `openalex-publishers` | Openalex Publishers |
| `openalex-venues` | Openalex Venues |
| `openalex-works` | OpenAlex works search |
| `ror-org-search` | Ror Org Search |
| `wikidata-universities` | Wikidata Universities |

## What you can expect

- Deep OpenAlex coverage — works, authors, institutions, venues, concepts, funders, publishers
- Crossref (works + funders) and DOAJ (open-access articles)
- ROR for research organisation identifiers

## What NOT to expect

- Full-text PDFs — rights-restricted upstream
- Private or institutional pre-prints (use arXiv directly for pre-print search — not yet in catalogue)

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
pilotctl --json send-message list-agents --data '/data {"category":"academic","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message openalex-works --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message openalex-works --data '/data {"search":"carbon capture","per_page":3}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
