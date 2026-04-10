# Video Production Pipeline

Deploy a video production pipeline with 3 agents that automate script writing, video editing coordination, and multi-platform distribution. Each agent owns one stage of the production workflow, passing assets downstream from brief to published content with performance tracking.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### scripter (Script Writer)
Generates video scripts, outlines, and storyboards from briefs and trending topics. Researches audience preferences and optimizes for engagement.

**Skills:** pilot-task-router, pilot-share, pilot-archive

### editor (Video Editor)
Coordinates editing tasks, manages asset libraries, and applies brand templates. Assembles final cuts from scripts, footage, and graphics.

**Skills:** pilot-task-chain, pilot-dataset, pilot-receipt

### distributor (Content Distributor)
Publishes to YouTube, TikTok, and social platforms. Tracks performance metrics across channels and reports on reach and engagement.

**Skills:** pilot-webhook-bridge, pilot-metrics, pilot-slack-bridge

## Data Flow

```
scripter    --> editor      : Approved scripts and storyboards (port 1002)
editor      --> distributor : Edited video packages with metadata (port 1002)
distributor --> external    : Publish notifications to platforms (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (script writing)
clawhub install pilot-task-router pilot-share pilot-archive
pilotctl set-hostname <your-prefix>-scripter

# On server 2 (video editing)
clawhub install pilot-task-chain pilot-dataset pilot-receipt
pilotctl set-hostname <your-prefix>-editor

# On server 3 (distribution)
clawhub install pilot-webhook-bridge pilot-metrics pilot-slack-bridge
pilotctl set-hostname <your-prefix>-distributor
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On scripter:
pilotctl handshake <your-prefix>-editor "setup: video-production-pipeline"
# On editor:
pilotctl handshake <your-prefix>-scripter "setup: video-production-pipeline"

# On editor:
pilotctl handshake <your-prefix>-distributor "setup: video-production-pipeline"
# On distributor:
pilotctl handshake <your-prefix>-editor "setup: video-production-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-editor — subscribe to scripts from scripter:
pilotctl subscribe <your-prefix>-scripter video-script

# On <your-prefix>-scripter — publish a script:
pilotctl publish <your-prefix>-editor video-script '{"title":"10 Tips for Productivity","duration_sec":480,"format":"short-form","scenes":5,"hook":"Did you know most people waste 3 hours a day?"}'

# On <your-prefix>-distributor — subscribe to edited videos:
pilotctl subscribe <your-prefix>-editor edited-video

# On <your-prefix>-editor — publish an edited video package:
pilotctl publish <your-prefix>-distributor edited-video '{"title":"10 Tips for Productivity","asset_url":"s3://videos/prod-tips-final.mp4","thumbnail":"s3://thumbs/prod-tips.jpg","captions":true}'

# On <your-prefix>-distributor — publish to platforms:
pilotctl publish <your-prefix>-distributor publish-notification '{"title":"10 Tips for Productivity","platforms":["youtube","tiktok"],"status":"published","youtube_id":"dQw4w9WgXcQ"}'
```
