---
name: pilot-podcast-production-setup
description: >
  Deploy a podcast production pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up an automated podcast production pipeline
  2. User is configuring an agent as part of a podcast production workflow
  3. User asks about automating research-to-distribution podcast workflows

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants a one-off webhook notification (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - podcast
  - production
  - media
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

# Podcast Production Setup

Deploy 3 agents that automate podcast production from research to distribution.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| researcher | `<prefix>-researcher` | pilot-discover, pilot-stream-data, pilot-archive | Finds trending topics, guest suggestions, and talking points |
| producer | `<prefix>-producer` | pilot-task-router, pilot-share, pilot-cron | Organizes show notes, talking points, and recording schedules |
| distributor | `<prefix>-distributor` | pilot-webhook-bridge, pilot-announce, pilot-slack-bridge | Publishes episodes to platforms and posts to social media |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For researcher:
clawhub install pilot-discover pilot-stream-data pilot-archive

# For producer:
clawhub install pilot-task-router pilot-share pilot-cron

# For distributor:
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/podcast-production.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### researcher
```json
{
  "setup": "podcast-production", "setup_name": "Podcast Production",
  "role": "researcher", "role_name": "Topic Researcher",
  "hostname": "<prefix>-researcher",
  "description": "Finds trending topics, guest suggestions, audience questions, and talking points for episodes.",
  "skills": {
    "pilot-discover": "Find trending topics, potential guests, and audience questions in the podcast niche.",
    "pilot-stream-data": "Stream real-time industry news and social signals for timely episode angles.",
    "pilot-archive": "Store episode briefs and source material for reference and audit trail."
  },
  "peers": [{"role": "producer", "hostname": "<prefix>-producer", "description": "Receives episode briefs and organizes production"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-producer", "port": 1002, "topic": "episode-brief", "description": "Episode briefs with topics, guests, and talking points"}],
  "handshakes_needed": ["<prefix>-producer"]
}
```

### producer
```json
{
  "setup": "podcast-production", "setup_name": "Podcast Production",
  "role": "producer", "role_name": "Episode Producer",
  "hostname": "<prefix>-producer",
  "description": "Organizes show notes, talking points, intros/outros, timestamps, and coordinates recording schedules.",
  "skills": {
    "pilot-task-router": "Route incoming episode briefs to the appropriate production template.",
    "pilot-share": "Send completed episode packages downstream to the distributor agent.",
    "pilot-cron": "Schedule recurring production tasks and recording reminders."
  },
  "peers": [
    {"role": "researcher", "hostname": "<prefix>-researcher", "description": "Sends episode briefs with topics and guests"},
    {"role": "distributor", "hostname": "<prefix>-distributor", "description": "Receives episode packages for distribution"}
  ],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-researcher", "port": 1002, "topic": "episode-brief", "description": "Episode briefs with topics, guests, and talking points"},
    {"direction": "send", "peer": "<prefix>-distributor", "port": 1002, "topic": "episode-package", "description": "Episode packages with show notes and timestamps"}
  ],
  "handshakes_needed": ["<prefix>-researcher", "<prefix>-distributor"]
}
```

### distributor
```json
{
  "setup": "podcast-production", "setup_name": "Podcast Production",
  "role": "distributor", "role_name": "Content Distributor",
  "hostname": "<prefix>-distributor",
  "description": "Publishes episodes to RSS feeds, Apple Podcasts, Spotify. Posts show notes and clips to social media.",
  "skills": {
    "pilot-webhook-bridge": "Push episode metadata to podcast platforms via webhook and trigger RSS updates.",
    "pilot-announce": "Broadcast publication events to internal teams and content calendar.",
    "pilot-slack-bridge": "Post episode summaries and links to the podcast team Slack channel."
  },
  "peers": [{"role": "producer", "hostname": "<prefix>-producer", "description": "Sends completed episode packages for distribution"}],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-producer", "port": 1002, "topic": "episode-package", "description": "Episode packages with show notes and timestamps"},
    {"direction": "send", "peer": "external", "port": 443, "topic": "publish-notification", "description": "Publish notifications to RSS, platforms, and social"}
  ],
  "handshakes_needed": ["<prefix>-producer"]
}
```

## Data Flows

- `researcher -> producer` : episode-brief (port 1002)
- `producer -> distributor` : episode-package (port 1002)
- `distributor -> external` : publish-notification via webhook (port 443)

## Handshakes

```bash
# researcher and producer handshake with each other:
pilotctl --json handshake <prefix>-producer "setup: podcast-production"
pilotctl --json handshake <prefix>-researcher "setup: podcast-production"

# producer and distributor handshake with each other:
pilotctl --json handshake <prefix>-distributor "setup: podcast-production"
pilotctl --json handshake <prefix>-producer "setup: podcast-production"
```

## Workflow Example

```bash
# On producer -- subscribe to episode briefs:
pilotctl --json subscribe <prefix>-researcher episode-brief

# On distributor -- subscribe to episode packages:
pilotctl --json subscribe <prefix>-producer episode-package

# On researcher -- publish an episode brief:
pilotctl --json publish <prefix>-producer episode-brief '{"topic":"Future of AI Agents","guests":["Jane Smith"],"talking_points":["autonomous deployments","agent collaboration"]}'

# On producer -- publish episode package to distributor:
pilotctl --json publish <prefix>-distributor episode-package '{"title":"EP42: Future of AI Agents","duration_minutes":45,"show_notes":"Deep dive into autonomous deployments.","timestamps":["00:00 Intro","12:30 Main topic","40:00 Wrap-up"]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
