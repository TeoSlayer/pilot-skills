# Release Management

Deploy an automated release pipeline with 3 agents that generate changelogs from merged PRs, manage semantic versioning and release tags, and announce releases across Slack, email, and documentation sites. Each agent handles a stage of the release process -- changelog generation, version coordination, and public announcement.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### changelog-bot (Changelog Bot)
Scans merged PRs and commits, generates release notes and changelogs automatically. Categorizes changes by type and extracts breaking changes.

**Skills:** pilot-github-bridge, pilot-share, pilot-archive

### version-manager (Version Manager)
Bumps semantic versions, tags releases, coordinates rollout schedules. Ensures version consistency across all release artifacts.

**Skills:** pilot-task-router, pilot-receipt, pilot-audit-log

### announcer (Release Announcer)
Posts release announcements to Slack, email lists, and documentation sites. Formats announcements with highlights and migration notes.

**Skills:** pilot-announce, pilot-slack-bridge, pilot-webhook-bridge

## Data Flow

```
changelog-bot   --> version-manager : Release notes with categorized changes (port 1002)
version-manager --> announcer       : Release tag with version and artifacts (port 1002)
announcer       --> external        : Release announcement via Slack and webhooks (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (changelog bot)
clawhub install pilot-github-bridge pilot-share pilot-archive
pilotctl set-hostname <your-prefix>-changelog-bot

# On server 2 (version manager)
clawhub install pilot-task-router pilot-receipt pilot-audit-log
pilotctl set-hostname <your-prefix>-version-manager

# On server 3 (release announcer)
clawhub install pilot-announce pilot-slack-bridge pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-announcer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On version-manager:
pilotctl handshake <your-prefix>-changelog-bot "setup: release-management"
# On changelog-bot:
pilotctl handshake <your-prefix>-version-manager "setup: release-management"
# On announcer:
pilotctl handshake <your-prefix>-version-manager "setup: release-management"
# On version-manager:
pilotctl handshake <your-prefix>-announcer "setup: release-management"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-version-manager — subscribe to release notes from changelog-bot:
pilotctl subscribe <your-prefix>-changelog-bot release-notes

# On <your-prefix>-announcer — subscribe to release tags from version-manager:
pilotctl subscribe <your-prefix>-version-manager release-tag

# On <your-prefix>-changelog-bot — publish release notes:
pilotctl publish <your-prefix>-version-manager release-notes '{"version":"1.5.0","date":"2026-04-10","changes":[{"type":"feature","description":"Add webhook retry logic"},{"type":"fix","description":"Fix race condition in event handler"}],"breaking":false}'

# On <your-prefix>-version-manager — publish a release tag:
pilotctl publish <your-prefix>-announcer release-tag '{"version":"v1.5.0","tag":"v1.5.0","artifacts":["linux-amd64","darwin-arm64"],"changelog_url":"https://example.com/releases/v1.5.0"}'

# The announcer receives the tag and dispatches announcements:
pilotctl publish <your-prefix>-announcer release-announcement '{"channel":"#releases","version":"v1.5.0","highlights":["Webhook retry logic","Race condition fix"],"migration_notes":"No breaking changes"}'
```
