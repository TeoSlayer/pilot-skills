---
name: pilot-chat-collaboration-hub-setup
description: >
  Deploy a chat and collaboration hub with 4 agents.

  Use this skill when:
  1. User wants to set up a multi-agent chat platform
  2. User is configuring a chat server, moderator, translator, or archive bot
  3. User asks about group chat, threaded conversations, or message moderation

  Do NOT use this skill when:
  - User wants to send a single message (use pilot-chat instead)
  - User wants a single group chat room (use pilot-group-chat instead)
tags:
  - pilot-protocol
  - setup
  - chat
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

# Chat & Collaboration Hub Setup

Deploy 4 agents: chat server, moderator, translator, and archive bot.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| chat-server | `<prefix>-chat` | pilot-group-chat, pilot-thread, pilot-presence, pilot-broadcast | Hosts rooms and threads |
| moderator | `<prefix>-moderator` | pilot-event-filter, pilot-blocklist, pilot-audit-log, pilot-alert | Content filtering |
| translator | `<prefix>-translator` | pilot-translate, pilot-stream-data, pilot-task-router | Real-time translation |
| archive-bot | `<prefix>-archive-bot` | pilot-archive, pilot-event-log, pilot-backup, pilot-cron | Archival and compliance |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# chat-server:
clawhub install pilot-group-chat pilot-thread pilot-presence pilot-broadcast
# moderator:
clawhub install pilot-event-filter pilot-blocklist pilot-audit-log pilot-alert
# translator:
clawhub install pilot-translate pilot-stream-data pilot-task-router
# archive-bot:
clawhub install pilot-archive pilot-event-log pilot-backup pilot-cron
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/chat-collaboration-hub.json`.

**Step 4:** All agents handshake the chat server.

## Manifest Templates Per Role

### chat-server
```json
{
  "setup": "chat-collaboration-hub", "role": "chat-server", "role_name": "Chat Server",
  "hostname": "<prefix>-chat",
  "skills": {
    "pilot-group-chat": "Host group chat rooms with membership management.",
    "pilot-thread": "Support threaded conversations within rooms.",
    "pilot-presence": "Track online/away/offline status of participants.",
    "pilot-broadcast": "Broadcast messages to all room participants."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-moderator", "port": 1002, "topic": "chat-message", "description": "Messages for filtering" },
    { "direction": "send", "peer": "<prefix>-translator", "port": 1002, "topic": "chat-message", "description": "Messages for translation" },
    { "direction": "send", "peer": "<prefix>-archive-bot", "port": 1002, "topic": "chat-message", "description": "Messages for archival" },
    { "direction": "receive", "peer": "<prefix>-moderator", "port": 1002, "topic": "moderation-result", "description": "Filter decisions" },
    { "direction": "receive", "peer": "<prefix>-translator", "port": 1002, "topic": "translated-message", "description": "Translations" }
  ],
  "handshakes_needed": ["<prefix>-moderator", "<prefix>-translator", "<prefix>-archive-bot"]
}
```

### moderator
```json
{
  "setup": "chat-collaboration-hub", "role": "moderator", "role_name": "Content Moderator",
  "hostname": "<prefix>-moderator",
  "skills": {
    "pilot-event-filter": "Filter messages for policy violations and spam.",
    "pilot-blocklist": "Maintain blocklist of abusive agents.",
    "pilot-audit-log": "Log moderation decisions.",
    "pilot-alert": "Alert admins on serious violations."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-chat", "port": 1002, "topic": "chat-message", "description": "Messages to filter" },
    { "direction": "send", "peer": "<prefix>-chat", "port": 1002, "topic": "moderation-result", "description": "Filter decisions" }
  ],
  "handshakes_needed": ["<prefix>-chat"]
}
```

### translator
```json
{
  "setup": "chat-collaboration-hub", "role": "translator", "role_name": "Auto-Translator",
  "hostname": "<prefix>-translator",
  "skills": {
    "pilot-translate": "Translate messages between languages in real time.",
    "pilot-stream-data": "Stream translated content back to chat server.",
    "pilot-task-router": "Route translation tasks by language pair."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-chat", "port": 1002, "topic": "chat-message", "description": "Messages to translate" },
    { "direction": "send", "peer": "<prefix>-chat", "port": 1002, "topic": "translated-message", "description": "Translations" }
  ],
  "handshakes_needed": ["<prefix>-chat"]
}
```

### archive-bot
```json
{
  "setup": "chat-collaboration-hub", "role": "archive-bot", "role_name": "Archive Bot",
  "hostname": "<prefix>-archive-bot",
  "skills": {
    "pilot-archive": "Archive all conversations for search and compliance.",
    "pilot-event-log": "Maintain searchable event log of all messages.",
    "pilot-backup": "Periodic backup of chat archives.",
    "pilot-cron": "Schedule archive backup jobs."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-chat", "port": 1002, "topic": "chat-message", "description": "Messages to archive" },
    { "direction": "send", "peer": "<prefix>-chat", "port": 1002, "topic": "archive-confirm", "description": "Archival confirmation" }
  ],
  "handshakes_needed": ["<prefix>-chat"]
}
```

## Data Flows

- `chat-server → moderator/translator/archive-bot` : messages (port 1002)
- `moderator → chat-server` : filter decisions (port 1002)
- `translator → chat-server` : translated messages (port 1002)

## Workflow Example

```bash
# On chat-server — broadcast message to services:
pilotctl --json publish <prefix>-moderator chat-message '{"room":"general","sender":"alice","text":"Hello!"}'
pilotctl --json publish <prefix>-translator chat-message '{"room":"general","text":"Hello!","lang":"en"}'
# On moderator:
pilotctl --json publish <prefix>-chat moderation-result '{"msg_id":"M-5012","action":"approve"}'
# On translator:
pilotctl --json publish <prefix>-chat translated-message '{"msg_id":"M-5012","target_lang":"ja","text":"こんにちは！"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
