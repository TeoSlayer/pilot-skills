---
name: pilot-meeting-assistant-setup
description: >
  Deploy a meeting assistant system with 3 agents.

  Use this skill when:
  1. User wants to set up an automated meeting assistant system
  2. User is configuring an agent as part of a meeting management workflow
  3. User asks about automating meeting scheduling, notes, and action tracking

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants a one-off scheduled task (use pilot-cron instead)
tags:
  - pilot-protocol
  - setup
  - meetings
  - productivity
  - collaboration
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

# Meeting Assistant Setup

Deploy 3 agents that automate meeting management from scheduling to action item tracking.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| scheduler | `<prefix>-scheduler` | pilot-cron, pilot-webhook-bridge, pilot-receipt | Manages calendar, sends invites, handles rescheduling |
| note-taker | `<prefix>-note-taker` | pilot-stream-data, pilot-share, pilot-archive | Captures notes, decisions, and summaries in structured format |
| action-tracker | `<prefix>-action-tracker` | pilot-task-router, pilot-alert, pilot-slack-bridge | Extracts action items, assigns owners, sends reminders |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For scheduler:
clawhub install pilot-cron pilot-webhook-bridge pilot-receipt

# For note-taker:
clawhub install pilot-stream-data pilot-share pilot-archive

# For action-tracker:
clawhub install pilot-task-router pilot-alert pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/meeting-assistant.json << 'MANIFEST'
<role-specific manifest from templates below>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### scheduler
```json
{
  "setup": "meeting-assistant", "setup_name": "Meeting Assistant",
  "role": "scheduler", "role_name": "Meeting Scheduler",
  "hostname": "<prefix>-scheduler",
  "description": "Manages calendar availability, sends invites, handles rescheduling and conflicts.",
  "skills": {
    "pilot-cron": "Schedule recurring meetings and send calendar reminders on time.",
    "pilot-webhook-bridge": "Sync meeting events with external calendar services via webhook.",
    "pilot-receipt": "Confirm meeting invitations were delivered and accepted by attendees."
  },
  "peers": [{"role": "note-taker", "hostname": "<prefix>-note-taker", "description": "Receives meeting started events for note capture"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-note-taker", "port": 1002, "topic": "meeting-started", "description": "Meeting started events with attendees and agenda"}],
  "handshakes_needed": ["<prefix>-note-taker"]
}
```

### note-taker
```json
{
  "setup": "meeting-assistant", "setup_name": "Meeting Assistant",
  "role": "note-taker", "role_name": "Note Taker",
  "hostname": "<prefix>-note-taker",
  "description": "Captures meeting notes, key decisions, and discussion summaries in structured format.",
  "skills": {
    "pilot-stream-data": "Stream live meeting content for real-time note capture.",
    "pilot-share": "Send structured meeting notes downstream to the action tracker.",
    "pilot-archive": "Store meeting notes and decision records for long-term reference."
  },
  "peers": [
    {"role": "scheduler", "hostname": "<prefix>-scheduler", "description": "Sends meeting started events with attendees and agenda"},
    {"role": "action-tracker", "hostname": "<prefix>-action-tracker", "description": "Receives meeting notes for action item extraction"}
  ],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-scheduler", "port": 1002, "topic": "meeting-started", "description": "Meeting started events with attendees and agenda"},
    {"direction": "send", "peer": "<prefix>-action-tracker", "port": 1002, "topic": "meeting-notes", "description": "Meeting notes with decisions and action items"}
  ],
  "handshakes_needed": ["<prefix>-scheduler", "<prefix>-action-tracker"]
}
```

### action-tracker
```json
{
  "setup": "meeting-assistant", "setup_name": "Meeting Assistant",
  "role": "action-tracker", "role_name": "Action Tracker",
  "hostname": "<prefix>-action-tracker",
  "description": "Extracts action items from notes, assigns owners, tracks completion, and sends reminders.",
  "skills": {
    "pilot-task-router": "Parse meeting notes and route action items to the appropriate owners.",
    "pilot-alert": "Fire reminders when action items approach or pass their due dates.",
    "pilot-slack-bridge": "Post action item summaries and reminders to team Slack channels."
  },
  "peers": [{"role": "note-taker", "hostname": "<prefix>-note-taker", "description": "Sends meeting notes with decisions and action items"}],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-note-taker", "port": 1002, "topic": "meeting-notes", "description": "Meeting notes with decisions and action items"},
    {"direction": "send", "peer": "external", "port": 443, "topic": "action-reminder", "description": "Action item reminders to owners"}
  ],
  "handshakes_needed": ["<prefix>-note-taker"]
}
```

## Data Flows

- `scheduler -> note-taker` : meeting-started (port 1002)
- `note-taker -> action-tracker` : meeting-notes (port 1002)
- `action-tracker -> external` : action-reminder via webhook (port 443)

## Handshakes

```bash
# scheduler and note-taker handshake with each other:
pilotctl --json handshake <prefix>-note-taker "setup: meeting-assistant"
pilotctl --json handshake <prefix>-scheduler "setup: meeting-assistant"

# note-taker and action-tracker handshake with each other:
pilotctl --json handshake <prefix>-action-tracker "setup: meeting-assistant"
pilotctl --json handshake <prefix>-note-taker "setup: meeting-assistant"
```

## Workflow Example

```bash
# On note-taker -- subscribe to meeting started events:
pilotctl --json subscribe <prefix>-scheduler meeting-started

# On action-tracker -- subscribe to meeting notes:
pilotctl --json subscribe <prefix>-note-taker meeting-notes

# On scheduler -- publish a meeting started event:
pilotctl --json publish <prefix>-note-taker meeting-started '{"meeting_id":"MTG-2026-0412","title":"Q2 Planning","attendees":["alice@acme.com","bob@acme.com"]}'

# On note-taker -- publish meeting notes to action tracker:
pilotctl --json publish <prefix>-action-tracker meeting-notes '{"meeting_id":"MTG-2026-0412","decisions":["Launch Project Alpha by June"],"action_items":[{"task":"Draft OKRs","owner":"alice@acme.com","due":"2026-04-17"}]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
