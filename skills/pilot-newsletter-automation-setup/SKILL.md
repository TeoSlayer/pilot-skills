---
name: pilot-newsletter-automation-setup
description: >
  Deploy an automated newsletter pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up a newsletter or email automation pipeline
  2. User is configuring an agent as part of a newsletter production workflow
  3. User asks about content curation, newsletter writing, or email dispatch across agents

  Do NOT use this skill when:
  - User wants to send a single announcement (use pilot-announce instead)
  - User wants to stream data once (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - newsletter
  - email
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

# Newsletter Automation Setup

Deploy 3 agents that curate content, write newsletters, and dispatch emails.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| curator | `<prefix>-curator` | pilot-discover, pilot-stream-data, pilot-archive | Aggregates trending content into curated digests |
| writer | `<prefix>-writer` | pilot-task-router, pilot-share, pilot-receipt | Transforms content into newsletter copy |
| mailer | `<prefix>-mailer` | pilot-webhook-bridge, pilot-announce, pilot-metrics | Dispatches emails, tracks delivery metrics |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For curator:
clawhub install pilot-discover pilot-stream-data pilot-archive

# For writer:
clawhub install pilot-task-router pilot-share pilot-receipt

# For mailer:
clawhub install pilot-webhook-bridge pilot-announce pilot-metrics
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/newsletter-automation.json << 'MANIFEST'
{
  "setup": "newsletter-automation",
  "setup_name": "Newsletter Automation",
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

### curator
```json
{
  "setup": "newsletter-automation", "setup_name": "Newsletter Automation",
  "role": "curator", "role_name": "Content Curator",
  "hostname": "<prefix>-curator",
  "description": "Aggregates trending articles, RSS feeds, and industry news into curated content digests.",
  "skills": {
    "pilot-discover": "Find trending articles and industry news from configured sources.",
    "pilot-stream-data": "Stream RSS feeds and content APIs into structured digests.",
    "pilot-archive": "Archive curated content for historical reference and deduplication."
  },
  "peers": [
    { "role": "writer", "hostname": "<prefix>-writer", "description": "Receives curated content for newsletter writing" },
    { "role": "mailer", "hostname": "<prefix>-mailer", "description": "Final stage — does not communicate directly" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-writer", "port": 1002, "topic": "content-digest", "description": "Curated content digest with sources and summaries" }
  ],
  "handshakes_needed": ["<prefix>-writer"]
}
```

### writer
```json
{
  "setup": "newsletter-automation", "setup_name": "Newsletter Automation",
  "role": "writer", "role_name": "Newsletter Writer",
  "hostname": "<prefix>-writer",
  "description": "Transforms curated content into engaging newsletter copy with subject lines and sections.",
  "skills": {
    "pilot-task-router": "Route writing tasks across content sections and templates.",
    "pilot-share": "Share draft previews with other agents for review.",
    "pilot-receipt": "Confirm receipt of curated content from curator."
  },
  "peers": [
    { "role": "curator", "hostname": "<prefix>-curator", "description": "Sends curated content digests" },
    { "role": "mailer", "hostname": "<prefix>-mailer", "description": "Receives newsletter drafts for delivery" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-curator", "port": 1002, "topic": "content-digest", "description": "Curated content digest with sources and summaries" },
    { "direction": "send", "peer": "<prefix>-mailer", "port": 1002, "topic": "newsletter-draft", "description": "Newsletter draft with subject line and HTML body" }
  ],
  "handshakes_needed": ["<prefix>-curator", "<prefix>-mailer"]
}
```

### mailer
```json
{
  "setup": "newsletter-automation", "setup_name": "Newsletter Automation",
  "role": "mailer", "role_name": "Email Dispatcher",
  "hostname": "<prefix>-mailer",
  "description": "Formats newsletters for email delivery, manages subscriber segments, tracks open rates.",
  "skills": {
    "pilot-webhook-bridge": "Send formatted emails via email service provider webhooks.",
    "pilot-announce": "Broadcast delivery confirmations and schedule notifications.",
    "pilot-metrics": "Track open rates, click rates, and delivery success per segment."
  },
  "peers": [
    { "role": "curator", "hostname": "<prefix>-curator", "description": "First stage — does not communicate directly" },
    { "role": "writer", "hostname": "<prefix>-writer", "description": "Sends newsletter drafts for delivery" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-writer", "port": 1002, "topic": "newsletter-draft", "description": "Newsletter draft with subject line and HTML body" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "email-dispatch", "description": "Email dispatch to subscriber segments" }
  ],
  "handshakes_needed": ["<prefix>-writer"]
}
```

## Data Flows

- `curator -> writer` : content-digest events (port 1002)
- `writer -> mailer` : newsletter-draft events (port 1002)
- `mailer -> external` : email-dispatch via webhook (port 443)

## Handshakes

```bash
# curator and writer handshake with each other:
pilotctl --json handshake <prefix>-writer "setup: newsletter-automation"
pilotctl --json handshake <prefix>-curator "setup: newsletter-automation"

# writer and mailer handshake with each other:
pilotctl --json handshake <prefix>-mailer "setup: newsletter-automation"
pilotctl --json handshake <prefix>-writer "setup: newsletter-automation"
```

## Workflow Example

```bash
# On writer — subscribe to content digests:
pilotctl --json subscribe <prefix>-curator content-digest

# On mailer — subscribe to newsletter drafts:
pilotctl --json subscribe <prefix>-writer newsletter-draft

# On curator — publish a content digest:
pilotctl --json publish <prefix>-writer content-digest '{"date":"2026-04-10","articles":[{"title":"AI Agents in Production","url":"https://example.com/ai-agents"}],"topic":"AI & DevOps"}'

# On writer — publish a newsletter draft:
pilotctl --json publish <prefix>-mailer newsletter-draft '{"subject":"This Week in AI","sections":[{"heading":"Top Story","body":"AI agents are going mainstream..."}]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
