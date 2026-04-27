---
name: pilot-service-agents-health
description: >
  Public-health and biomedical APIs — ClinicalTrials.gov, openFDA, CDC, WHO, ClinVar, DailyMed, disease.sh.

  Use this skill when:
  1. Searching active/past clinical trials by condition, sponsor, phase
  2. Drug label, adverse-event, or interaction lookups (openFDA, DailyMed)
  3. COVID / epidemiological stats, WHO global health indicators

  Do NOT use this skill when:
  - Running LLM-based medical-advice chats (agents return data only)
  - Accessing PHI or private clinical records — these are public endpoints
  - Nutrition / food-product data (use pilot-service-agents-food)
tags:
  - pilot-protocol
  - service-agents
  - health
  - biomedical
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

# pilot-service-agents-health

Public-health and biomedical APIs — ClinicalTrials.gov, openFDA, CDC, WHO, ClinVar, DailyMed, disease.sh.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `cdc-covid-vax` | CDC COVID-19 vaccination data by jurisdiction |
| `clinicaltrials-search` | ClinicalTrials.gov v2 studies search |
| `clinvar-esearch` | Clinvar Esearch |
| `dailymed-spl` | Dailymed Spl |
| `disease-sh-countries` | COVID-19 per-country live statistics |
| `disease-sh-covid` | disease.sh COVID-19 country statistics |
| `mesh-lookup` | Mesh Lookup |
| `ncbi-gene-esearch` | Ncbi Gene Esearch |
| `ncbi-pubmed-esearch` | Ncbi Pubmed Esearch |
| `noaa-tides` | NOAA Tides & Currents water level data |
| `open-disease-covid` | COVID-19 and flu live global counts |
| `openfda-adverse-events` | Openfda Adverse Events |
| `openfda-device-event` | FDA medical device adverse event reports |
| `openfda-drug` | openFDA drug label search - FDA-approved drug data |
| `openfda-drug-events` | openFDA drug adverse event reports |
| `openfda-food-recall` | FDA food product recall enforcement reports |
| `openfda-ndc` | Openfda Ndc |
| `openfdadevice-recall` | Openfdadevice Recall |
| `pubmed-esearch-v2` | PubMed article metadata by PMID |
| `rxnorm-drug` | RxNorm drug name/ingredient lookup (NIH/NLM) |
| `rxnorm-drugs` | Rxnorm Drugs |
| `wger-exercises` | Exercise/workout database with muscle groups |
| `who-disease-outbreaks` | Who Disease Outbreaks |
| `who-gho-data-life-expect` | Who Gho Data Life Expect |
| `who-gho-data-mortality` | Who Gho Data Mortality |
| `who-gho-indicator` | WHO Global Health Observatory indicators |
| `who-gho-indicators-list` | Who Gho Indicators List |

## What you can expect

- Regulatory and surveillance data — FDA drug labels, CDC indicators, disease.sh country COVID stats
- ClinicalTrials.gov v2 study search with rich filters
- WHO Global Health Observatory (mortality, life-expectancy, disease outbreaks)

## What NOT to expect

- Personal health records — all data is anonymised/public
- Diagnostic advice — outputs are raw structured records
- Live provider directories (not in catalogue)

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
pilotctl --json send-message list-agents --data '/data {"category":"health","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message clinicaltrials-search --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message clinicaltrials-search --data '/data {"query":"sleep apnea","status":"RECRUITING"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
