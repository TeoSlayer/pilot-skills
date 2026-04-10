# Translation Pipeline

Deploy an automated translation pipeline with 3 agents that extract content from sources, translate it between languages, and review translations for quality before publishing. Each agent handles a stage of the translation process -- extraction, translation, and quality review -- so multilingual content is produced reliably at scale.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### extractor (Content Extractor)
Pulls text content from documents, websites, or APIs for translation. Preserves structure and metadata for downstream processing.

**Skills:** pilot-stream-data, pilot-share, pilot-archive

### translator (Translation Engine)
Translates extracted content between languages, preserving formatting and context. Handles batch and parallel translation tasks.

**Skills:** pilot-task-router, pilot-task-parallel, pilot-receipt

### reviewer (Quality Reviewer)
Reviews translations for accuracy, cultural nuance, and consistency. Publishes approved translations to external systems.

**Skills:** pilot-review, pilot-alert, pilot-webhook-bridge

## Data Flow

```
extractor  --> translator : Source content with structure and metadata (port 1002)
translator --> reviewer   : Translated content with language pair and confidence (port 1002)
reviewer   --> external   : Approved translation published to destination (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (content extractor)
clawhub install pilot-stream-data pilot-share pilot-archive
pilotctl set-hostname <your-prefix>-extractor

# On server 2 (translation engine)
clawhub install pilot-task-router pilot-task-parallel pilot-receipt
pilotctl set-hostname <your-prefix>-translator

# On server 3 (quality reviewer)
clawhub install pilot-review pilot-alert pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-reviewer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On translator:
pilotctl handshake <your-prefix>-extractor "setup: translation-pipeline"
# On extractor:
pilotctl handshake <your-prefix>-translator "setup: translation-pipeline"
# On reviewer:
pilotctl handshake <your-prefix>-translator "setup: translation-pipeline"
# On translator:
pilotctl handshake <your-prefix>-reviewer "setup: translation-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-translator — subscribe to source content from extractor:
pilotctl subscribe <your-prefix>-extractor source-content

# On <your-prefix>-reviewer — subscribe to translated content from translator:
pilotctl subscribe <your-prefix>-translator translated-content

# On <your-prefix>-extractor — publish source content:
pilotctl publish <your-prefix>-translator source-content '{"source_lang":"en","target_lang":"es","content_type":"article","segments":[{"id":"s1","text":"Autonomous agents are transforming how teams deploy software."}]}'

# On <your-prefix>-translator — publish translated content:
pilotctl publish <your-prefix>-reviewer translated-content '{"source_lang":"en","target_lang":"es","segments":[{"id":"s1","original":"Autonomous agents are transforming how teams deploy software.","translated":"Los agentes autonomos estan transformando la forma en que los equipos despliegan software.","confidence":0.94}]}'

# The reviewer approves and publishes:
pilotctl publish <your-prefix>-reviewer approved-translation '{"target_lang":"es","status":"approved","segments":1,"destination":"https://example.com/api/translations"}'
```
