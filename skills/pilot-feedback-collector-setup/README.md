# Feedback Collector

Deploy a feedback collection pipeline with 3 agents that automate feedback intake, sentiment analysis, and actionable routing. Each agent handles one stage of the pipeline, turning raw customer feedback from surveys, NPS forms, and support tickets into scored insights routed to the right team.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### intake (Feedback Intake)
Collects feedback from surveys, NPS forms, app reviews, and support tickets. Normalizes inputs into a consistent format and forwards to analysis.

**Skills:** pilot-stream-data, pilot-chat, pilot-archive

### analyzer (Sentiment Analyzer)
Scores sentiment, extracts themes, identifies trending complaints and praise. Outputs enriched feedback records with sentiment scores and topic tags.

**Skills:** pilot-event-filter, pilot-metrics, pilot-task-router

### router (Feedback Router)
Routes actionable feedback to product, engineering, or support teams via Slack and webhook. Escalates critical issues and aggregates trend reports.

**Skills:** pilot-alert, pilot-slack-bridge, pilot-webhook-bridge

## Data Flow

```
intake   --> analyzer : Raw feedback normalized from all sources (port 1002)
analyzer --> router   : Scored feedback with sentiment and themes (port 1002)
router   --> external : Feedback alerts to product, engineering, support (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (feedback intake)
clawhub install pilot-stream-data pilot-chat pilot-archive
pilotctl set-hostname <your-prefix>-intake

# On server 2 (sentiment analyzer)
clawhub install pilot-event-filter pilot-metrics pilot-task-router
pilotctl set-hostname <your-prefix>-analyzer

# On server 3 (feedback router)
clawhub install pilot-alert pilot-slack-bridge pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-router
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# intake <-> analyzer
# On intake:
pilotctl handshake <your-prefix>-analyzer "setup: feedback-collector"
# On analyzer:
pilotctl handshake <your-prefix>-intake "setup: feedback-collector"

# analyzer <-> router
# On analyzer:
pilotctl handshake <your-prefix>-router "setup: feedback-collector"
# On router:
pilotctl handshake <your-prefix>-analyzer "setup: feedback-collector"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-analyzer -- subscribe to raw feedback from intake:
pilotctl subscribe <your-prefix>-intake raw-feedback

# On <your-prefix>-router -- subscribe to scored feedback:
pilotctl subscribe <your-prefix>-analyzer scored-feedback

# On <your-prefix>-intake -- publish raw feedback:
pilotctl publish <your-prefix>-analyzer raw-feedback '{"source":"nps_survey","score":3,"customer":"user-8291","text":"The new dashboard is confusing. I cannot find my billing page anymore.","timestamp":"2025-03-15T14:22:00Z"}'

# On <your-prefix>-analyzer -- publish scored feedback to the router:
pilotctl publish <your-prefix>-router scored-feedback '{"source":"nps_survey","sentiment":-0.6,"themes":["ux","navigation","billing"],"priority":"high","customer":"user-8291","text":"The new dashboard is confusing. I cannot find my billing page anymore.","trending":true}'

# The router sends actionable feedback to the right team:
pilotctl publish <your-prefix>-router feedback-alert '{"channel":"#product-feedback","text":"High-priority UX issue (trending): Dashboard navigation confusion affecting billing access","team":"product","priority":"high","ticket_url":"https://support.acme.com/tickets/4821"}'
```
