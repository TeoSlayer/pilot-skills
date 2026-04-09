---
name: pilot-social-media-manager-setup
description: >
  Deploy a social media management system with 3 agents.

  Use this skill when:
  1. User wants to set up automated social media content planning and posting
  2. User is configuring an agent as part of a social media management workflow
  3. User asks about automating social media scheduling, creation, or analytics

  Do NOT use this skill when:
  - User wants to collect metrics from a single source (use pilot-metrics instead)
  - User wants to schedule a one-off task (use pilot-cron instead)
tags:
  - pilot-protocol
  - setup
  - social-media
  - marketing
  - analytics
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

# Social Media Manager Setup

Deploy 3 agents that plan, create, and analyze social media content in a feedback loop.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| planner | `<prefix>-planner` | pilot-cron, pilot-stream-data, pilot-metrics | Analyzes trends and plans content calendar |
| creator | `<prefix>-creator` | pilot-task-router, pilot-share, pilot-receipt | Generates platform-specific posts from briefs |
| analyst | `<prefix>-analyst` | pilot-metrics, pilot-event-log, pilot-alert | Tracks engagement and feeds insights to planner |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For planner:
clawhub install pilot-cron pilot-stream-data pilot-metrics

# For creator:
clawhub install pilot-task-router pilot-share pilot-receipt

# For analyst:
clawhub install pilot-metrics pilot-event-log pilot-alert
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/social-media-manager.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### planner
```json
{
  "setup": "social-media-manager",
  "setup_name": "Social Media Manager",
  "role": "planner",
  "role_name": "Content Planner",
  "hostname": "<prefix>-planner",
  "description": "Analyzes trends, competitor activity, and audience engagement to plan a content calendar and optimal posting times.",
  "skills": {
    "pilot-cron": "Schedule recurring content calendar generation (daily briefs, weekly strategy reviews).",
    "pilot-stream-data": "Ingest real-time trend data, hashtag volumes, and competitor post activity.",
    "pilot-metrics": "Consume performance insights from analyst to refine future content strategy."
  },
  "peers": [
    { "role": "creator", "hostname": "<prefix>-creator", "description": "Receives content briefs and produces platform posts" },
    { "role": "analyst", "hostname": "<prefix>-analyst", "description": "Sends performance insights and optimization recommendations" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-creator", "port": 1002, "topic": "content-brief", "description": "Content briefs with platform targets and posting schedule" },
    { "direction": "receive", "peer": "<prefix>-analyst", "port": 1002, "topic": "performance-insight", "description": "Performance insights and optimization recommendations" }
  ],
  "handshakes_needed": ["<prefix>-creator", "<prefix>-analyst"]
}
```

### creator
```json
{
  "setup": "social-media-manager",
  "setup_name": "Social Media Manager",
  "role": "creator",
  "role_name": "Content Creator",
  "hostname": "<prefix>-creator",
  "description": "Generates platform-specific posts (LinkedIn, X, Instagram) from the planner's brief in the brand voice.",
  "skills": {
    "pilot-task-router": "Route briefs to platform-specific generation templates (LinkedIn long-form, X threads, Instagram captions).",
    "pilot-share": "Send published post metadata to the analyst for tracking.",
    "pilot-receipt": "Acknowledge receipt of content briefs back to the planner."
  },
  "peers": [
    { "role": "planner", "hostname": "<prefix>-planner", "description": "Sends content briefs with topics and platform targets" },
    { "role": "analyst", "hostname": "<prefix>-analyst", "description": "Receives published post metadata for tracking" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-planner", "port": 1002, "topic": "content-brief", "description": "Content briefs with platform targets and posting schedule" },
    { "direction": "send", "peer": "<prefix>-analyst", "port": 1002, "topic": "post-published", "description": "Published post metadata for performance tracking" }
  ],
  "handshakes_needed": ["<prefix>-planner", "<prefix>-analyst"]
}
```

### analyst
```json
{
  "setup": "social-media-manager",
  "setup_name": "Social Media Manager",
  "role": "analyst",
  "role_name": "Performance Analyst",
  "hostname": "<prefix>-analyst",
  "description": "Tracks cross-platform engagement metrics, identifies top performers, and feeds insights back to the planner.",
  "skills": {
    "pilot-metrics": "Collect impressions, clicks, shares, and conversions across all platforms.",
    "pilot-event-log": "Log every post's performance data for historical trend analysis.",
    "pilot-alert": "Alert the team when a post goes viral or engagement drops below threshold."
  },
  "peers": [
    { "role": "creator", "hostname": "<prefix>-creator", "description": "Sends published post metadata for tracking" },
    { "role": "planner", "hostname": "<prefix>-planner", "description": "Receives performance insights for strategy refinement" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-creator", "port": 1002, "topic": "post-published", "description": "Published post metadata for performance tracking" },
    { "direction": "send", "peer": "<prefix>-planner", "port": 1002, "topic": "performance-insight", "description": "Performance insights and optimization recommendations" }
  ],
  "handshakes_needed": ["<prefix>-creator", "<prefix>-planner"]
}
```

## Data Flows

- `planner -> creator` : content-brief (port 1002)
- `creator -> analyst` : post-published (port 1002)
- `analyst -> planner` : performance-insight (port 1002)

## Handshakes

```bash
# All three agents form a cycle, so each pair needs bidirectional handshakes:
# planner <-> creator:
pilotctl --json handshake <prefix>-creator "setup: social-media-manager"
pilotctl --json handshake <prefix>-planner "setup: social-media-manager"

# creator <-> analyst:
pilotctl --json handshake <prefix>-analyst "setup: social-media-manager"
pilotctl --json handshake <prefix>-creator "setup: social-media-manager"

# analyst <-> planner:
pilotctl --json handshake <prefix>-planner "setup: social-media-manager"
pilotctl --json handshake <prefix>-analyst "setup: social-media-manager"
```

## Workflow Example

```bash
# On creator -- subscribe to content briefs:
pilotctl --json subscribe <prefix>-planner content-brief
# On analyst -- subscribe to published posts:
pilotctl --json subscribe <prefix>-creator post-published
# On planner -- subscribe to performance insights:
pilotctl --json subscribe <prefix>-analyst performance-insight

# On planner -- publish a content brief:
pilotctl --json publish <prefix>-creator content-brief '{"platforms":["linkedin","x"],"topic":"AI in DevOps","tone":"professional"}'

# On analyst -- publish insights back to planner:
pilotctl --json publish <prefix>-planner performance-insight '{"top_platform":"linkedin","engagement_rate":4.2}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
