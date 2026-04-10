# Podcast Production

Deploy a podcast production pipeline where a researcher finds trending topics and guest suggestions, a producer organizes show notes and coordinates recording schedules, and a distributor publishes episodes across platforms and social media. The three agents form an assembly line that turns raw research into published podcast episodes with minimal human intervention.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### researcher (Topic Researcher)
Finds trending topics, guest suggestions, audience questions, and talking points. Packages findings into structured episode briefs with source links and audience engagement data.

**Skills:** pilot-discover, pilot-stream-data, pilot-archive

### producer (Episode Producer)
Organizes show notes, talking points, intros/outros, and timestamps. Coordinates recording schedules and assembles episode packages ready for distribution.

**Skills:** pilot-task-router, pilot-share, pilot-cron

### distributor (Content Distributor)
Publishes episodes to RSS feeds, Apple Podcasts, and Spotify. Posts show notes and clips to social media and notifies subscribers via Slack.

**Skills:** pilot-webhook-bridge, pilot-announce, pilot-slack-bridge

## Data Flow

```
researcher  --> producer    : Episode briefs with topics, guests, and talking points (port 1002)
producer    --> distributor : Episode packages with show notes and timestamps (port 1002)
distributor --> external    : Publish notifications to RSS, platforms, and social (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (topic researcher)
clawhub install pilot-discover pilot-stream-data pilot-archive
pilotctl set-hostname <your-prefix>-researcher

# On server 2 (episode producer)
clawhub install pilot-task-router pilot-share pilot-cron
pilotctl set-hostname <your-prefix>-producer

# On server 3 (content distributor)
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
pilotctl set-hostname <your-prefix>-distributor
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# researcher <-> producer
# On researcher:
pilotctl handshake <your-prefix>-producer "setup: podcast-production"
# On producer:
pilotctl handshake <your-prefix>-researcher "setup: podcast-production"

# producer <-> distributor
# On producer:
pilotctl handshake <your-prefix>-distributor "setup: podcast-production"
# On distributor:
pilotctl handshake <your-prefix>-producer "setup: podcast-production"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-producer -- subscribe to episode briefs:
pilotctl subscribe <your-prefix>-researcher episode-brief

# On <your-prefix>-distributor -- subscribe to episode packages:
pilotctl subscribe <your-prefix>-producer episode-package

# On <your-prefix>-researcher -- publish an episode brief:
pilotctl publish <your-prefix>-producer episode-brief '{"topic":"Future of AI Agents in DevOps","guests":["Jane Smith","Alex Chen"],"talking_points":["autonomous deployments","self-healing infrastructure","agent collaboration"],"audience_questions":["How do agents handle rollbacks?","What about security?"],"trending_score":87}'

# On <your-prefix>-producer -- publish an episode package to the distributor:
pilotctl publish <your-prefix>-distributor episode-package '{"title":"EP42: Future of AI Agents in DevOps","duration_minutes":45,"show_notes":"Deep dive into autonomous deployments with Jane Smith and Alex Chen.","timestamps":["00:00 Intro","03:15 Guest backgrounds","12:30 Autonomous deployments","28:00 Security concerns","40:00 Wrap-up"],"status":"ready"}'

# The distributor publishes to platforms and notifies social:
pilotctl publish <your-prefix>-distributor publish-notification '{"channel":"#podcast","text":"Published: EP42 - Future of AI Agents in DevOps","platforms":["rss","apple_podcasts","spotify"],"url":"https://podcast.acme.com/ep42"}'
```
