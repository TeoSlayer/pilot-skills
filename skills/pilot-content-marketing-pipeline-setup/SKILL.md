---
name: pilot-content-marketing-pipeline-setup
description: >
  Deploy a content marketing pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up an automated content production pipeline
  2. User is configuring an agent as part of a content marketing workflow
  3. User asks about automating research-to-publication content workflows

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants a one-off webhook notification (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - content
  - marketing
  - pipeline
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

# Content Marketing Pipeline Setup

Deploy 3 agents that automate content production from research to publication.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| researcher | `<prefix>-researcher` | pilot-discover, pilot-stream-data, pilot-archive | Gathers topics, keywords, and sources into research briefs |
| writer | `<prefix>-writer` | pilot-task-router, pilot-share, pilot-receipt | Transforms briefs into polished articles and social copy |
| publisher | `<prefix>-publisher` | pilot-webhook-bridge, pilot-announce, pilot-slack-bridge | Formats for CMS, schedules publication, notifies stakeholders |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For researcher:
clawhub install pilot-discover pilot-stream-data pilot-archive

# For writer:
clawhub install pilot-task-router pilot-share pilot-receipt

# For publisher:
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/content-marketing-pipeline.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### researcher
```json
{
  "setup": "content-marketing-pipeline",
  "setup_name": "Content Marketing Pipeline",
  "role": "researcher",
  "role_name": "Content Researcher",
  "hostname": "<prefix>-researcher",
  "description": "Gathers trending topics, keywords, competitor content, and source material. Packages findings into structured research briefs.",
  "skills": {
    "pilot-discover": "Find trending topics, competitor articles, and keyword opportunities in the target niche.",
    "pilot-stream-data": "Stream real-time industry news feeds and social signals to identify timely content angles.",
    "pilot-archive": "Store research briefs and source material for audit trail and future reference."
  },
  "peers": [
    { "role": "writer", "hostname": "<prefix>-writer", "description": "Receives research briefs and produces content" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-writer", "port": 1002, "topic": "research-brief", "description": "Research briefs with topics, keywords, and sources" }
  ],
  "handshakes_needed": ["<prefix>-writer"]
}
```

### writer
```json
{
  "setup": "content-marketing-pipeline",
  "setup_name": "Content Marketing Pipeline",
  "role": "writer",
  "role_name": "Content Writer",
  "hostname": "<prefix>-writer",
  "description": "Transforms research briefs into polished articles, blog posts, and social copy in the brand voice.",
  "skills": {
    "pilot-task-router": "Route incoming research briefs to the appropriate content template (blog, social, newsletter).",
    "pilot-share": "Send completed draft content downstream to the publisher agent.",
    "pilot-receipt": "Acknowledge receipt of research briefs back to the researcher."
  },
  "peers": [
    { "role": "researcher", "hostname": "<prefix>-researcher", "description": "Sends research briefs with topics and sources" },
    { "role": "publisher", "hostname": "<prefix>-publisher", "description": "Receives draft content for formatting and publication" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-researcher", "port": 1002, "topic": "research-brief", "description": "Research briefs with topics, keywords, and sources" },
    { "direction": "send", "peer": "<prefix>-publisher", "port": 1002, "topic": "draft-content", "description": "Draft content with metadata and formatting notes" }
  ],
  "handshakes_needed": ["<prefix>-researcher", "<prefix>-publisher"]
}
```

### publisher
```json
{
  "setup": "content-marketing-pipeline",
  "setup_name": "Content Marketing Pipeline",
  "role": "publisher",
  "role_name": "Content Publisher",
  "hostname": "<prefix>-publisher",
  "description": "Formats final content for CMS, generates metadata, schedules publication, and notifies stakeholders.",
  "skills": {
    "pilot-webhook-bridge": "Push published content to CMS via webhook and trigger build pipelines.",
    "pilot-announce": "Broadcast publication events to internal teams and content calendar.",
    "pilot-slack-bridge": "Post publication summaries and links to the content team Slack channel."
  },
  "peers": [
    { "role": "writer", "hostname": "<prefix>-writer", "description": "Sends completed draft content for publication" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-writer", "port": 1002, "topic": "draft-content", "description": "Draft content with metadata and formatting notes" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "publish-notify", "description": "Publication notifications to CMS and Slack" }
  ],
  "handshakes_needed": ["<prefix>-writer"]
}
```

## Data Flows

- `researcher -> writer` : research-brief (port 1002)
- `writer -> publisher` : draft-content (port 1002)
- `publisher -> external` : publish-notify via webhook (port 443)

## Handshakes

```bash
# researcher and writer handshake with each other:
pilotctl --json handshake <prefix>-writer "setup: content-marketing-pipeline"
pilotctl --json handshake <prefix>-researcher "setup: content-marketing-pipeline"

# writer and publisher handshake with each other:
pilotctl --json handshake <prefix>-publisher "setup: content-marketing-pipeline"
pilotctl --json handshake <prefix>-writer "setup: content-marketing-pipeline"
```

## Workflow Example

```bash
# On writer -- subscribe to research briefs:
pilotctl --json subscribe <prefix>-researcher research-brief

# On publisher -- subscribe to draft content:
pilotctl --json subscribe <prefix>-writer draft-content

# On researcher -- publish a research brief:
pilotctl --json publish <prefix>-writer research-brief '{"topic":"AI Agent Frameworks","keywords":["agents","orchestration"],"sources":["arxiv:2406.01234"]}'

# On writer -- publish draft to publisher:
pilotctl --json publish <prefix>-publisher draft-content '{"title":"The Rise of AI Agents","slug":"ai-agents-2026","word_count":1850,"format":"markdown"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
