---
name: pilot-release-management-setup
description: >
  Deploy an automated release management pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up a release management or changelog automation pipeline
  2. User is configuring an agent as part of a release versioning workflow
  3. User asks about generating changelogs, bumping versions, or announcing releases across agents

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants to send a one-off announcement (use pilot-announce instead)
tags:
  - pilot-protocol
  - setup
  - release
  - changelog
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

# Release Management Setup

Deploy 3 agents that generate changelogs, manage versions, and announce releases.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| changelog-bot | `<prefix>-changelog-bot` | pilot-github-bridge, pilot-share, pilot-archive | Scans merged PRs and commits, generates release notes |
| version-manager | `<prefix>-version-manager` | pilot-task-router, pilot-receipt, pilot-audit-log | Bumps versions, tags releases, coordinates rollout |
| announcer | `<prefix>-announcer` | pilot-announce, pilot-slack-bridge, pilot-webhook-bridge | Posts release announcements to Slack, email, docs |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For changelog-bot:
clawhub install pilot-github-bridge pilot-share pilot-archive

# For version-manager:
clawhub install pilot-task-router pilot-receipt pilot-audit-log

# For announcer:
clawhub install pilot-announce pilot-slack-bridge pilot-webhook-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/release-management.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### changelog-bot
```json
{
  "setup": "release-management", "setup_name": "Release Management",
  "role": "changelog-bot", "role_name": "Changelog Bot",
  "hostname": "<prefix>-changelog-bot",
  "description": "Scans merged PRs and commits, generates release notes and changelogs automatically.",
  "skills": {
    "pilot-github-bridge": "Watch for merged PRs, fetch commit history and PR metadata.",
    "pilot-share": "Share generated changelogs with version manager.",
    "pilot-archive": "Archive previous release notes for historical reference."
  },
  "peers": [
    { "role": "version-manager", "hostname": "<prefix>-version-manager", "description": "Receives release notes for versioning" },
    { "role": "announcer", "hostname": "<prefix>-announcer", "description": "Final stage — does not communicate directly" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-version-manager", "port": 1002, "topic": "release-notes", "description": "Release notes with categorized changes" }
  ],
  "handshakes_needed": ["<prefix>-version-manager"]
}
```

### version-manager
```json
{
  "setup": "release-management", "setup_name": "Release Management",
  "role": "version-manager", "role_name": "Version Manager",
  "hostname": "<prefix>-version-manager",
  "description": "Bumps semantic versions, tags releases, coordinates rollout schedules.",
  "skills": {
    "pilot-task-router": "Route version bump decisions based on change categories.",
    "pilot-receipt": "Confirm receipt of release notes from changelog bot.",
    "pilot-audit-log": "Log all version bumps and release tags for traceability."
  },
  "peers": [
    { "role": "changelog-bot", "hostname": "<prefix>-changelog-bot", "description": "Sends release notes with categorized changes" },
    { "role": "announcer", "hostname": "<prefix>-announcer", "description": "Receives release tags for announcement" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-changelog-bot", "port": 1002, "topic": "release-notes", "description": "Release notes with categorized changes" },
    { "direction": "send", "peer": "<prefix>-announcer", "port": 1002, "topic": "release-tag", "description": "Release tag with version and artifacts" }
  ],
  "handshakes_needed": ["<prefix>-changelog-bot", "<prefix>-announcer"]
}
```

### announcer
```json
{
  "setup": "release-management", "setup_name": "Release Management",
  "role": "announcer", "role_name": "Release Announcer",
  "hostname": "<prefix>-announcer",
  "description": "Posts release announcements to Slack, email lists, and documentation sites.",
  "skills": {
    "pilot-announce": "Broadcast release announcements to all subscribed channels.",
    "pilot-slack-bridge": "Post formatted release notes to Slack channels.",
    "pilot-webhook-bridge": "Notify documentation sites and email services via webhooks."
  },
  "peers": [
    { "role": "changelog-bot", "hostname": "<prefix>-changelog-bot", "description": "First stage — does not communicate directly" },
    { "role": "version-manager", "hostname": "<prefix>-version-manager", "description": "Sends release tags for announcement" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-version-manager", "port": 1002, "topic": "release-tag", "description": "Release tag with version and artifacts" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "release-announcement", "description": "Release announcement via Slack and webhooks" }
  ],
  "handshakes_needed": ["<prefix>-version-manager"]
}
```

## Data Flows

- `changelog-bot -> version-manager` : release-notes events (port 1002)
- `version-manager -> announcer` : release-tag events (port 1002)
- `announcer -> external` : release-announcement via webhook (port 443)

## Handshakes

```bash
# changelog-bot and version-manager handshake with each other:
pilotctl --json handshake <prefix>-version-manager "setup: release-management"
pilotctl --json handshake <prefix>-changelog-bot "setup: release-management"

# version-manager and announcer handshake with each other:
pilotctl --json handshake <prefix>-announcer "setup: release-management"
pilotctl --json handshake <prefix>-version-manager "setup: release-management"
```

## Workflow Example

```bash
# On version-manager — subscribe to release notes:
pilotctl --json subscribe <prefix>-changelog-bot release-notes

# On announcer — subscribe to release tags:
pilotctl --json subscribe <prefix>-version-manager release-tag

# On changelog-bot — publish release notes:
pilotctl --json publish <prefix>-version-manager release-notes '{"version":"1.5.0","changes":[{"type":"feature","description":"Add webhook retry logic"}],"breaking":false}'

# On version-manager — publish a release tag:
pilotctl --json publish <prefix>-announcer release-tag '{"version":"v1.5.0","artifacts":["linux-amd64","darwin-arm64"]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
