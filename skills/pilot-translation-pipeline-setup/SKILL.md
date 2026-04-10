---
name: pilot-translation-pipeline-setup
description: >
  Deploy an automated translation pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up a translation or localization pipeline
  2. User is configuring an agent as part of a multilingual content workflow
  3. User asks about extracting content, translating text, or reviewing translations across agents

  Do NOT use this skill when:
  - User wants to translate a single piece of text (use pilot-task-router instead)
  - User wants to stream data once (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - translation
  - localization
license: AGPL-3.0
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - clawhub
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Translation Pipeline Setup

Deploy 3 agents that extract content, translate between languages, and review quality.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| extractor | `<prefix>-extractor` | pilot-stream-data, pilot-share, pilot-archive | Pulls text from documents, websites, or APIs |
| translator | `<prefix>-translator` | pilot-task-router, pilot-task-parallel, pilot-receipt | Translates content between languages |
| reviewer | `<prefix>-reviewer` | pilot-review, pilot-alert, pilot-webhook-bridge | Reviews quality, publishes approved translations |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For extractor:
clawhub install pilot-stream-data pilot-share pilot-archive

# For translator:
clawhub install pilot-task-router pilot-task-parallel pilot-receipt

# For reviewer:
clawhub install pilot-review pilot-alert pilot-webhook-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/translation-pipeline.json << 'MANIFEST'
{
  "setup": "translation-pipeline",
  "setup_name": "Translation Pipeline",
  "role": "<ROLE_ID>",
  "role_name": "<ROLE_NAME>",
  "hostname": "<prefix>-<role>",
  "description": "<ROLE_DESCRIPTION>",
  "skills": { "<skill>": "<contextual description>" },
  "peers": [ { "role": "...", "hostname": "...", "description": "..." } ],
  "data_flows": [ { "direction": "send|receive", "peer": "...", "port": 1002, "topic": "...", "description": "..." } ],
  "handshakes_needed": [ "<peer-hostname>" ]
}
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### extractor
```json
{
  "setup": "translation-pipeline", "setup_name": "Translation Pipeline",
  "role": "extractor", "role_name": "Content Extractor",
  "hostname": "<prefix>-extractor",
  "description": "Pulls text content from documents, websites, or APIs for translation.",
  "skills": {
    "pilot-stream-data": "Stream content from URLs, files, and APIs into structured segments.",
    "pilot-share": "Share extracted content with translator for processing.",
    "pilot-archive": "Archive source content for reference and reprocessing."
  },
  "peers": [
    { "role": "translator", "hostname": "<prefix>-translator", "description": "Receives source content for translation" },
    { "role": "reviewer", "hostname": "<prefix>-reviewer", "description": "Final stage — does not communicate directly" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-translator", "port": 1002, "topic": "source-content", "description": "Source content with structure and metadata" }
  ],
  "handshakes_needed": ["<prefix>-translator"]
}
```

### translator
```json
{
  "setup": "translation-pipeline", "setup_name": "Translation Pipeline",
  "role": "translator", "role_name": "Translation Engine",
  "hostname": "<prefix>-translator",
  "description": "Translates extracted content between languages, preserving formatting and context.",
  "skills": {
    "pilot-task-router": "Route translation tasks to appropriate language models.",
    "pilot-task-parallel": "Run parallel translations for multi-segment documents.",
    "pilot-receipt": "Confirm receipt of source content from extractor."
  },
  "peers": [
    { "role": "extractor", "hostname": "<prefix>-extractor", "description": "Sends source content for translation" },
    { "role": "reviewer", "hostname": "<prefix>-reviewer", "description": "Receives translated content for quality review" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-extractor", "port": 1002, "topic": "source-content", "description": "Source content with structure and metadata" },
    { "direction": "send", "peer": "<prefix>-reviewer", "port": 1002, "topic": "translated-content", "description": "Translated content with language pair and confidence" }
  ],
  "handshakes_needed": ["<prefix>-extractor", "<prefix>-reviewer"]
}
```

### reviewer
```json
{
  "setup": "translation-pipeline", "setup_name": "Translation Pipeline",
  "role": "reviewer", "role_name": "Quality Reviewer",
  "hostname": "<prefix>-reviewer",
  "description": "Reviews translations for accuracy, cultural nuance, and consistency.",
  "skills": {
    "pilot-review": "Score translation quality and flag segments needing revision.",
    "pilot-alert": "Alert on low-confidence translations requiring human review.",
    "pilot-webhook-bridge": "Publish approved translations to destination systems via webhook."
  },
  "peers": [
    { "role": "extractor", "hostname": "<prefix>-extractor", "description": "First stage — does not communicate directly" },
    { "role": "translator", "hostname": "<prefix>-translator", "description": "Sends translated content for quality review" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-translator", "port": 1002, "topic": "translated-content", "description": "Translated content with language pair and confidence" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "approved-translation", "description": "Approved translation published to destination" }
  ],
  "handshakes_needed": ["<prefix>-translator"]
}
```

## Data Flows

- `extractor -> translator` : source-content events (port 1002)
- `translator -> reviewer` : translated-content events (port 1002)
- `reviewer -> external` : approved-translation via webhook (port 443)

## Handshakes

```bash
# extractor and translator handshake with each other:
pilotctl --json handshake <prefix>-translator "setup: translation-pipeline"
pilotctl --json handshake <prefix>-extractor "setup: translation-pipeline"

# translator and reviewer handshake with each other:
pilotctl --json handshake <prefix>-reviewer "setup: translation-pipeline"
pilotctl --json handshake <prefix>-translator "setup: translation-pipeline"
```

## Workflow Example

```bash
# On translator — subscribe to source content:
pilotctl --json subscribe <prefix>-extractor source-content

# On reviewer — subscribe to translated content:
pilotctl --json subscribe <prefix>-translator translated-content

# On extractor — publish source content:
pilotctl --json publish <prefix>-translator source-content '{"source_lang":"en","target_lang":"es","segments":[{"id":"s1","text":"Autonomous agents are transforming software deployment."}]}'

# On translator — publish translated content:
pilotctl --json publish <prefix>-reviewer translated-content '{"source_lang":"en","target_lang":"es","segments":[{"id":"s1","translated":"Los agentes autonomos estan transformando el despliegue de software.","confidence":0.94}]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
