# Content Marketing Pipeline Setup

Deploy a content production pipeline where a researcher gathers trending topics and source material, a writer transforms briefs into polished articles and social copy, and a publisher formats content for your CMS and schedules publication. The three agents form an assembly line that turns raw research into published content with minimal human intervention.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### researcher (Content Researcher)
Gathers trending topics, keywords, competitor content, and source material. Packages findings into structured research briefs with citations and SEO recommendations.

**Skills:** pilot-discover, pilot-stream-data, pilot-archive

### writer (Content Writer)
Transforms research briefs into polished articles, blog posts, and social copy in the brand voice. Handles tone, structure, and SEO optimization before passing drafts downstream.

**Skills:** pilot-task-router, pilot-share, pilot-receipt

### publisher (Content Publisher)
Formats final content for CMS, generates metadata (tags, excerpts, Open Graph), schedules publication, and notifies stakeholders via Slack or webhook.

**Skills:** pilot-webhook-bridge, pilot-announce, pilot-slack-bridge

## Data Flow

```
researcher --> writer    : Research briefs with topics, keywords, and sources (port 1002)
writer     --> publisher : Draft content with metadata and formatting notes (port 1002)
publisher  --> external  : Publish notifications to CMS and Slack (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (content researcher)
clawhub install pilot-discover pilot-stream-data pilot-archive
pilotctl set-hostname <your-prefix>-researcher

# On server 2 (content writer)
clawhub install pilot-task-router pilot-share pilot-receipt
pilotctl set-hostname <your-prefix>-writer

# On server 3 (content publisher)
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
pilotctl set-hostname <your-prefix>-publisher
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# researcher <-> writer
# On researcher:
pilotctl handshake <your-prefix>-writer "setup: content-marketing-pipeline"
# On writer:
pilotctl handshake <your-prefix>-researcher "setup: content-marketing-pipeline"

# writer <-> publisher
# On writer:
pilotctl handshake <your-prefix>-publisher "setup: content-marketing-pipeline"
# On publisher:
pilotctl handshake <your-prefix>-writer "setup: content-marketing-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-writer -- subscribe to research briefs:
pilotctl subscribe <your-prefix>-researcher research-brief

# On <your-prefix>-publisher -- subscribe to draft content:
pilotctl subscribe <your-prefix>-writer draft-content

# On <your-prefix>-researcher -- publish a research brief:
pilotctl publish <your-prefix>-writer research-brief '{"topic":"AI Agent Frameworks 2026","keywords":["autonomous agents","multi-agent","orchestration"],"competitors":["langchain","crewai"],"sources":["arxiv:2406.01234","techcrunch.com/ai-agents"],"seo_difficulty":"medium"}'

# On <your-prefix>-writer -- publish a draft to the publisher:
pilotctl publish <your-prefix>-publisher draft-content '{"title":"The Rise of AI Agent Frameworks","slug":"ai-agent-frameworks-2026","word_count":1850,"format":"markdown","tags":["ai","agents","frameworks"],"status":"ready"}'

# The publisher formats and pushes to CMS, then notifies Slack:
pilotctl publish <your-prefix>-publisher publish-notify '{"channel":"#content","text":"Published: The Rise of AI Agent Frameworks","url":"https://blog.acme.com/ai-agent-frameworks-2026"}'
```
