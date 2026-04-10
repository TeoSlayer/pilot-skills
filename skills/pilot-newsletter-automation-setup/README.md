# Newsletter Automation

Deploy an automated newsletter pipeline with 3 agents that curate trending content, transform it into polished newsletter copy, and dispatch emails to subscriber segments. Each agent handles a stage of the production process -- curation, writing, and delivery -- so newsletters go out on schedule without manual effort.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### curator (Content Curator)
Aggregates trending articles, RSS feeds, and industry news into curated content digests. Filters for relevance and deduplicates sources.

**Skills:** pilot-discover, pilot-stream-data, pilot-archive

### writer (Newsletter Writer)
Transforms curated content into engaging newsletter copy with subject lines and sections. Maintains consistent tone and formatting.

**Skills:** pilot-task-router, pilot-share, pilot-receipt

### mailer (Email Dispatcher)
Formats newsletters for email delivery, manages subscriber segments, tracks open rates. Sends final emails and records delivery metrics.

**Skills:** pilot-webhook-bridge, pilot-announce, pilot-metrics

## Data Flow

```
curator --> writer   : Curated content digest with sources and summaries (port 1002)
writer  --> mailer   : Newsletter draft with subject line and HTML body (port 1002)
mailer  --> external : Email dispatch to subscriber segments (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (content curator)
clawhub install pilot-discover pilot-stream-data pilot-archive
pilotctl set-hostname <your-prefix>-curator

# On server 2 (newsletter writer)
clawhub install pilot-task-router pilot-share pilot-receipt
pilotctl set-hostname <your-prefix>-writer

# On server 3 (email dispatcher)
clawhub install pilot-webhook-bridge pilot-announce pilot-metrics
pilotctl set-hostname <your-prefix>-mailer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On writer:
pilotctl handshake <your-prefix>-curator "setup: newsletter-automation"
# On curator:
pilotctl handshake <your-prefix>-writer "setup: newsletter-automation"
# On mailer:
pilotctl handshake <your-prefix>-writer "setup: newsletter-automation"
# On writer:
pilotctl handshake <your-prefix>-mailer "setup: newsletter-automation"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-writer — subscribe to content digests from curator:
pilotctl subscribe <your-prefix>-curator content-digest

# On <your-prefix>-mailer — subscribe to newsletter drafts from writer:
pilotctl subscribe <your-prefix>-writer newsletter-draft

# On <your-prefix>-curator — publish a content digest:
pilotctl publish <your-prefix>-writer content-digest '{"date":"2026-04-10","articles":[{"title":"AI Agents in Production","url":"https://example.com/ai-agents","summary":"How teams are deploying autonomous agents at scale."}],"topic":"AI & DevOps"}'

# On <your-prefix>-writer — publish a newsletter draft:
pilotctl publish <your-prefix>-mailer newsletter-draft '{"subject":"This Week in AI & DevOps","sections":[{"heading":"Top Story","body":"AI agents are going mainstream in production environments..."}],"format":"html"}'

# The mailer receives the draft and dispatches emails:
pilotctl publish <your-prefix>-mailer email-dispatch '{"segment":"ai-enthusiasts","recipients":1250,"subject":"This Week in AI & DevOps","status":"queued"}'
```
