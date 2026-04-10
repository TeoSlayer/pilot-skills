---
name: pilot-video-production-pipeline-setup
description: >
  Deploy a video production pipeline with 3 agents that automate script writing,
  editing coordination, and multi-platform distribution.

  Use this skill when:
  1. User wants to set up a video production or content creation pipeline
  2. User is configuring an agent as part of a video editing or publishing workflow
  3. User asks about automating video scripts, editing tasks, or multi-platform distribution

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants a one-off webhook notification (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - video
  - content
  - production
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

# Video Production Pipeline Setup

Deploy 3 agents that automate video production from script to multi-platform publish.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| scripter | `<prefix>-scripter` | pilot-task-router, pilot-share, pilot-archive | Generates scripts, outlines, and storyboards from briefs |
| editor | `<prefix>-editor` | pilot-task-chain, pilot-dataset, pilot-receipt | Coordinates editing tasks, manages assets, applies templates |
| distributor | `<prefix>-distributor` | pilot-webhook-bridge, pilot-metrics, pilot-slack-bridge | Publishes to platforms, tracks performance metrics |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# scripter:
clawhub install pilot-task-router pilot-share pilot-archive
# editor:
clawhub install pilot-task-chain pilot-dataset pilot-receipt
# distributor:
clawhub install pilot-webhook-bridge pilot-metrics pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/video-production-pipeline.json << 'MANIFEST'
<USE ROLE TEMPLATE BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### scripter
```json
{"setup":"video-production-pipeline","setup_name":"Video Production Pipeline","role":"scripter","role_name":"Script Writer","hostname":"<prefix>-scripter","description":"Generates video scripts, outlines, and storyboards from briefs and trending topics.","skills":{"pilot-task-router":"Route briefs to appropriate script templates based on format and audience.","pilot-share":"Share completed scripts and storyboards with editor.","pilot-archive":"Archive all script drafts and revisions for reference."},"peers":[{"role":"editor","hostname":"<prefix>-editor","description":"Receives approved scripts for editing"}],"data_flows":[{"direction":"send","peer":"<prefix>-editor","port":1002,"topic":"video-script","description":"Approved scripts and storyboards"}],"handshakes_needed":["<prefix>-editor"]}
```

### editor
```json
{"setup":"video-production-pipeline","setup_name":"Video Production Pipeline","role":"editor","role_name":"Video Editor","hostname":"<prefix>-editor","description":"Coordinates editing tasks, manages asset libraries, applies brand templates.","skills":{"pilot-task-chain":"Chain editing subtasks — cuts, transitions, color grade, audio mix.","pilot-dataset":"Manage asset library — footage, graphics, music, brand templates.","pilot-receipt":"Confirm receipt of scripts and acknowledge edit completion."},"peers":[{"role":"scripter","hostname":"<prefix>-scripter","description":"Sends approved scripts"},{"role":"distributor","hostname":"<prefix>-distributor","description":"Receives edited video packages"}],"data_flows":[{"direction":"receive","peer":"<prefix>-scripter","port":1002,"topic":"video-script","description":"Approved scripts and storyboards"},{"direction":"send","peer":"<prefix>-distributor","port":1002,"topic":"edited-video","description":"Edited video packages with metadata"}],"handshakes_needed":["<prefix>-scripter","<prefix>-distributor"]}
```

### distributor
```json
{"setup":"video-production-pipeline","setup_name":"Video Production Pipeline","role":"distributor","role_name":"Content Distributor","hostname":"<prefix>-distributor","description":"Publishes to YouTube, TikTok, and social platforms. Tracks performance metrics.","skills":{"pilot-webhook-bridge":"Push publish events to YouTube, TikTok, and social platform APIs.","pilot-metrics":"Track views, engagement, click-through rates across platforms.","pilot-slack-bridge":"Post publish confirmations and performance summaries to Slack."},"peers":[{"role":"editor","hostname":"<prefix>-editor","description":"Sends edited video packages"}],"data_flows":[{"direction":"receive","peer":"<prefix>-editor","port":1002,"topic":"edited-video","description":"Edited video packages with metadata"},{"direction":"send","peer":"external","port":443,"topic":"publish-notification","description":"Publish notifications to platforms"}],"handshakes_needed":["<prefix>-editor"]}
```

## Data Flows

- `scripter -> editor` : video-script events (port 1002)
- `editor -> distributor` : edited-video events (port 1002)
- `distributor -> platforms` : publish notifications via webhook (port 443)

## Handshakes

```bash
# scripter <-> editor:
pilotctl --json handshake <prefix>-editor "setup: video-production-pipeline"
pilotctl --json handshake <prefix>-scripter "setup: video-production-pipeline"
# editor <-> distributor:
pilotctl --json handshake <prefix>-distributor "setup: video-production-pipeline"
pilotctl --json handshake <prefix>-editor "setup: video-production-pipeline"
```

## Workflow Example

```bash
# On editor — subscribe to scripts:
pilotctl --json subscribe <prefix>-scripter video-script
# On distributor — subscribe to edited videos:
pilotctl --json subscribe <prefix>-editor edited-video
# On scripter — publish a script:
pilotctl --json publish <prefix>-editor video-script '{"title":"10 Tips for Productivity","duration_sec":480,"scenes":5}'
# On editor — publish edited video:
pilotctl --json publish <prefix>-distributor edited-video '{"title":"10 Tips for Productivity","asset_url":"s3://videos/final.mp4"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
