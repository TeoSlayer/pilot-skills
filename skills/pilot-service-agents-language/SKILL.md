---
name: pilot-service-agents-language
description: >
  Language and NLP services — translation, text-to-speech, dictionaries, word tools, Bible text, linguistic corpora.

  Use this skill when:
  1. Translating text between languages (gcp-translate, premium)
  2. Finding synonyms, rhymes, related words (Datamuse)
  3. Fetching word definitions or dictionary entries

  Do NOT use this skill when:
  - Running your own LLM inference — these are specific narrow NLP APIs
  - Document summarisation (call any agent's /summary subcommand instead)
tags:
  - pilot-protocol
  - service-agents
  - language
  - nlp
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

# pilot-service-agents-language

Language and NLP services — translation, text-to-speech, dictionaries, word tools, Bible text, linguistic corpora.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `bible-api` | Biblical text across translations |
| `datamuse-sug` | Datamuse Sug |
| `datamuse-words` | Word finder: rhymes, related, semantic |
| `free-dictionary-en` | English word definitions and phonetics |
| `gcp-translate` | Google Cloud Translation (500K chars/mo free) |
| `gcp-tts-voices` | Google Text-to-Speech voice catalog |
| `genderize` | Predict gender from first name |
| `libretranslate-languages` | Libretranslate Languages |
| `mymemory-translate` | MyMemory machine translation (50+ languages) |
| `nationalize` | Predict nationality from name |
| `purgomalum-profanity` | Profanity/content filter for text moderation |
| `quran-cloud` | Quranic text with translations |
| `spellcheck-api` | Spellcheck Api |
| `urban-dictionary` | Crowdsourced slang dictionary |
| `wikimedia-langlinks` | Wikimedia Langlinks |
| `wiktionary-define` | Wiktionary Define |

## What you can expect

- Google Cloud Translation (premium) + Text-to-Speech voice catalogue (premium)
- Datamuse suggestions/words, Free Dictionary, Bible passages

## What NOT to expect

- OCR, speech recognition, or arbitrary generative text
- Guaranteed dialect / register fidelity — upstreams vary

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

## Workflow Example

```bash
# 1. Fresh discovery — the catalogue grows, never hard-code
pilotctl --json send-message list-agents --data '/data {"category":"language","limit":20}'
pilotctl --json inbox

# 2. Read the contract of a specific agent
pilotctl --json send-message datamuse-words --data '/help'
pilotctl --json inbox

# 3. Query it
pilotctl --json send-message datamuse-words --data '/data {"ml":"ringing in the ears"}'
pilotctl --json inbox
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
joined to network 9.
