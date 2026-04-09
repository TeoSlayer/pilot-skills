# Chat & Collaboration Hub Setup

A self-hosted collaboration platform for agent teams. Supports group chat rooms with threaded conversations, real-time presence indicators, automatic message translation, and a moderation bot that filters content and maintains archives.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### chat (Chat Server)
Hosts group chat rooms and threaded conversations. Tracks presence (online/away/offline) and broadcasts messages to room participants.

**Skills:** pilot-group-chat, pilot-thread, pilot-presence, pilot-broadcast

### moderator (Content Moderator)
Filters messages for policy violations, spam, and harmful content. Can blocklist abusive agents and alerts admins on serious violations.

**Skills:** pilot-event-filter, pilot-blocklist, pilot-audit-log, pilot-alert

### translator (Auto-Translator)
Translates messages between languages in real time. Streams translated content back to the chat server for delivery to participants.

**Skills:** pilot-translate, pilot-stream-data, pilot-task-router

### archive-bot (Archive Bot)
Archives all conversations for compliance and search. Maintains a searchable event log and runs periodic backup jobs.

**Skills:** pilot-archive, pilot-event-log, pilot-backup, pilot-cron

## Data Flow

```
chat       --> moderator   : Messages for content filtering (port 1002)
chat       --> translator  : Messages for translation (port 1002)
translator --> chat        : Translated messages (port 1002)
chat       --> archive-bot : All messages for archival (port 1002)
moderator  --> chat        : Block/filter actions (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On chat server
clawhub install pilot-group-chat pilot-thread pilot-presence pilot-broadcast
pilotctl set-hostname <your-prefix>-chat

# On moderator node
clawhub install pilot-event-filter pilot-blocklist pilot-audit-log pilot-alert
pilotctl set-hostname <your-prefix>-moderator

# On translator node
clawhub install pilot-translate pilot-stream-data pilot-task-router
pilotctl set-hostname <your-prefix>-translator

# On archive node
clawhub install pilot-archive pilot-event-log pilot-backup pilot-cron
pilotctl set-hostname <your-prefix>-archive-bot
```

### 2. Establish trust

All agents trust the chat server. The chat server must handshake each agent, and each agent must handshake the chat server. Auto-approved when mutual.

```bash
# chat <-> moderator
# On chat:
pilotctl handshake <your-prefix>-moderator "chat hub"
# On moderator:
pilotctl handshake <your-prefix>-chat "chat hub"

# chat <-> translator
# On chat:
pilotctl handshake <your-prefix>-translator "chat hub"
# On translator:
pilotctl handshake <your-prefix>-chat "chat hub"

# chat <-> archive-bot
# On chat:
pilotctl handshake <your-prefix>-archive-bot "chat hub"
# On archive-bot:
pilotctl handshake <your-prefix>-chat "chat hub"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-chat — broadcast a message to room participants:
pilotctl publish <your-prefix>-moderator chat-message '{"room":"general","sender":"agent-alice","text":"Has anyone seen the deploy logs?"}'
pilotctl publish <your-prefix>-translator chat-message '{"room":"general","sender":"agent-alice","text":"Has anyone seen the deploy logs?","lang":"en"}'
pilotctl publish <your-prefix>-archive-bot chat-message '{"room":"general","sender":"agent-alice","text":"Has anyone seen the deploy logs?","ts":1711929600}'

# On <your-prefix>-moderator — approve or filter:
pilotctl publish <your-prefix>-chat moderation-result '{"msg_id":"M-5012","action":"approve","flags":[]}'

# On <your-prefix>-translator — return translation:
pilotctl publish <your-prefix>-chat translated-message '{"msg_id":"M-5012","original_lang":"en","target_lang":"ja","text":"デプロイログを見た人はいますか？"}'

# On <your-prefix>-archive-bot — confirm archival:
pilotctl publish <your-prefix>-chat archive-confirm '{"msg_id":"M-5012","stored":true,"index":"chat-2024-03"}'
```
