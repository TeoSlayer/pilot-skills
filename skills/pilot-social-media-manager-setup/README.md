# Social Media Manager Setup

Deploy a social media management system where a planner analyzes trends and audience data to build a content calendar, a creator generates platform-specific posts from those briefs, and an analyst tracks engagement metrics and feeds performance insights back to the planner. The three agents form a continuous feedback loop that improves content strategy over time.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### planner (Content Planner)
Analyzes trends, competitor activity, and audience engagement to plan a content calendar and determine optimal posting times for each platform.

**Skills:** pilot-cron, pilot-stream-data, pilot-metrics

### creator (Content Creator)
Generates platform-specific posts (LinkedIn, X, Instagram) from the planner's brief, adapting tone, format, and hashtags to each platform's best practices.

**Skills:** pilot-task-router, pilot-share, pilot-receipt

### analyst (Performance Analyst)
Tracks cross-platform engagement metrics (impressions, clicks, shares, conversions), identifies top-performing content patterns, and feeds actionable insights back to the planner.

**Skills:** pilot-metrics, pilot-event-log, pilot-alert

## Data Flow

```
planner  --> creator  : Content briefs with platform targets and posting schedule (port 1002)
creator  --> analyst  : Published post metadata for performance tracking (port 1002)
analyst  --> planner  : Performance insights and optimization recommendations (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (content planner)
clawhub install pilot-cron pilot-stream-data pilot-metrics
pilotctl set-hostname <your-prefix>-planner

# On server 2 (content creator)
clawhub install pilot-task-router pilot-share pilot-receipt
pilotctl set-hostname <your-prefix>-creator

# On server 3 (performance analyst)
clawhub install pilot-metrics pilot-event-log pilot-alert
pilotctl set-hostname <your-prefix>-analyst
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# planner <-> creator
# On planner:
pilotctl handshake <your-prefix>-creator "setup: social-media-manager"
# On creator:
pilotctl handshake <your-prefix>-planner "setup: social-media-manager"

# creator <-> analyst
# On creator:
pilotctl handshake <your-prefix>-analyst "setup: social-media-manager"
# On analyst:
pilotctl handshake <your-prefix>-creator "setup: social-media-manager"

# analyst <-> planner
# On analyst:
pilotctl handshake <your-prefix>-planner "setup: social-media-manager"
# On planner:
pilotctl handshake <your-prefix>-analyst "setup: social-media-manager"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-creator -- subscribe to content briefs:
pilotctl subscribe <your-prefix>-planner content-brief

# On <your-prefix>-analyst -- subscribe to published posts:
pilotctl subscribe <your-prefix>-creator post-published

# On <your-prefix>-planner -- subscribe to performance insights:
pilotctl subscribe <your-prefix>-analyst performance-insight

# On <your-prefix>-planner -- publish a content brief:
pilotctl publish <your-prefix>-creator content-brief '{"platforms":["linkedin","x"],"topic":"AI in DevOps","angle":"practical tips","tone":"professional","post_time":"2026-04-10T09:00:00Z","hashtags":["#AIDevOps","#Automation"]}'

# On <your-prefix>-creator -- publish post metadata after posting:
pilotctl publish <your-prefix>-analyst post-published '{"post_id":"li-92841","platform":"linkedin","topic":"AI in DevOps","posted_at":"2026-04-10T09:00:00Z","char_count":1200,"hashtags":["#AIDevOps","#Automation"]}'

# On <your-prefix>-analyst -- publish insights back to planner:
pilotctl publish <your-prefix>-planner performance-insight '{"period":"2026-W15","top_platform":"linkedin","top_topic":"AI in DevOps","impressions":12400,"engagement_rate":4.2,"recommendation":"Increase LinkedIn frequency, morning posts outperform afternoon by 35%"}'
```
