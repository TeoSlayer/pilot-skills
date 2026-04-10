# Meeting Assistant

Deploy a meeting assistant system where a scheduler manages calendar availability and sends invites, a note-taker captures meeting notes and key decisions in structured format, and an action tracker extracts action items and sends reminders. The three agents form an end-to-end workflow that turns scheduled meetings into tracked outcomes with minimal human intervention.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### scheduler (Meeting Scheduler)
Manages calendar availability, sends meeting invites, handles rescheduling and conflicts. Notifies downstream agents when meetings start.

**Skills:** pilot-cron, pilot-webhook-bridge, pilot-receipt

### note-taker (Note Taker)
Captures meeting notes, key decisions, and discussion summaries in structured format. Packages notes with attendees, timestamps, and decision records.

**Skills:** pilot-stream-data, pilot-share, pilot-archive

### action-tracker (Action Tracker)
Extracts action items from meeting notes, assigns owners, tracks completion status, and sends reminders for overdue items via Slack.

**Skills:** pilot-task-router, pilot-alert, pilot-slack-bridge

## Data Flow

```
scheduler      --> note-taker     : Meeting started events with attendees and agenda (port 1002)
note-taker     --> action-tracker : Meeting notes with decisions and action items (port 1002)
action-tracker --> external       : Action item reminders to owners (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (meeting scheduler)
clawhub install pilot-cron pilot-webhook-bridge pilot-receipt
pilotctl set-hostname <your-prefix>-scheduler

# On server 2 (note taker)
clawhub install pilot-stream-data pilot-share pilot-archive
pilotctl set-hostname <your-prefix>-note-taker

# On server 3 (action tracker)
clawhub install pilot-task-router pilot-alert pilot-slack-bridge
pilotctl set-hostname <your-prefix>-action-tracker
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# scheduler <-> note-taker
# On scheduler:
pilotctl handshake <your-prefix>-note-taker "setup: meeting-assistant"
# On note-taker:
pilotctl handshake <your-prefix>-scheduler "setup: meeting-assistant"

# note-taker <-> action-tracker
# On note-taker:
pilotctl handshake <your-prefix>-action-tracker "setup: meeting-assistant"
# On action-tracker:
pilotctl handshake <your-prefix>-note-taker "setup: meeting-assistant"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-note-taker -- subscribe to meeting started events:
pilotctl subscribe <your-prefix>-scheduler meeting-started

# On <your-prefix>-action-tracker -- subscribe to meeting notes:
pilotctl subscribe <your-prefix>-note-taker meeting-notes

# On <your-prefix>-scheduler -- publish a meeting started event:
pilotctl publish <your-prefix>-note-taker meeting-started '{"meeting_id":"MTG-2026-0412","title":"Q2 Planning Review","attendees":["alice@acme.com","bob@acme.com","carol@acme.com"],"agenda":["Q1 retrospective","Q2 OKRs","Resource allocation"],"started_at":"2026-04-10T10:00:00Z"}'

# On <your-prefix>-note-taker -- publish meeting notes to the action tracker:
pilotctl publish <your-prefix>-action-tracker meeting-notes '{"meeting_id":"MTG-2026-0412","title":"Q2 Planning Review","decisions":["Increase hiring budget by 15%","Launch Project Alpha by June"],"action_items":[{"task":"Draft Q2 OKR document","owner":"alice@acme.com","due":"2026-04-17"},{"task":"Schedule Project Alpha kickoff","owner":"bob@acme.com","due":"2026-04-14"}],"summary":"Team aligned on Q2 priorities with focus on Project Alpha launch."}'

# The action tracker sends reminders to owners:
pilotctl publish <your-prefix>-action-tracker action-reminder '{"channel":"#team-ops","text":"Action item due in 3 days: Draft Q2 OKR document (owner: alice@acme.com)","meeting_id":"MTG-2026-0412","url":"https://notes.acme.com/mtg-2026-0412"}'
```
