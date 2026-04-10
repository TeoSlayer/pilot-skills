# Sales Pipeline

Deploy a sales pipeline with 4 agents that automate lead generation, qualification, personalized outreach, and CRM synchronization. Each agent handles one stage of the funnel, passing enriched data downstream so deals flow from raw prospect to closed-won without manual handoff.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### prospector (Lead Prospector)
Identifies potential leads from web scraping, social signals, and inbound forms. Scores leads by fit using firmographic and behavioral signals.

**Skills:** pilot-discover, pilot-stream-data, pilot-metrics

### qualifier (Lead Qualifier)
Evaluates leads against ICP criteria, enriches with firmographic data, and categorizes by tier (hot, warm, cold).

**Skills:** pilot-event-filter, pilot-task-router, pilot-dataset

### outreach (Outreach Agent)
Generates personalized email sequences, tracks engagement (opens, clicks, replies), and handles follow-ups on cadence.

**Skills:** pilot-email-bridge, pilot-cron, pilot-receipt

### crm-sync (CRM Sync Agent)
Syncs all pipeline activity to CRM via webhook, maintains deal stages, and reports forecasts to Slack.

**Skills:** pilot-webhook-bridge, pilot-audit-log, pilot-slack-bridge

## Data Flow

```
prospector --> qualifier  : Raw leads with fit scores (port 1002)
qualifier  --> outreach   : Qualified leads with tier and enrichment (port 1002)
outreach   --> crm-sync   : Engagement events — opens, replies, meetings (port 1002)
crm-sync   --> external   : CRM updates and forecast reports (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (lead prospecting)
clawhub install pilot-discover pilot-stream-data pilot-metrics
pilotctl set-hostname <your-prefix>-prospector

# On server 2 (lead qualification)
clawhub install pilot-event-filter pilot-task-router pilot-dataset
pilotctl set-hostname <your-prefix>-qualifier

# On server 3 (outreach)
clawhub install pilot-email-bridge pilot-cron pilot-receipt
pilotctl set-hostname <your-prefix>-outreach

# On server 4 (CRM sync)
clawhub install pilot-webhook-bridge pilot-audit-log pilot-slack-bridge
pilotctl set-hostname <your-prefix>-crm-sync
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On prospector:
pilotctl handshake <your-prefix>-qualifier "setup: sales-pipeline"
# On qualifier:
pilotctl handshake <your-prefix>-prospector "setup: sales-pipeline"

# On qualifier:
pilotctl handshake <your-prefix>-outreach "setup: sales-pipeline"
# On outreach:
pilotctl handshake <your-prefix>-qualifier "setup: sales-pipeline"

# On outreach:
pilotctl handshake <your-prefix>-crm-sync "setup: sales-pipeline"
# On crm-sync:
pilotctl handshake <your-prefix>-outreach "setup: sales-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-qualifier — subscribe to raw leads from prospector:
pilotctl subscribe <your-prefix>-prospector raw-lead

# On <your-prefix>-prospector — publish a raw lead:
pilotctl publish <your-prefix>-qualifier raw-lead '{"company":"Initech","domain":"initech.com","source":"linkedin","fit_score":82,"employees":450}'

# On <your-prefix>-outreach — subscribe to qualified leads:
pilotctl subscribe <your-prefix>-qualifier qualified-lead

# On <your-prefix>-qualifier — publish a qualified lead:
pilotctl publish <your-prefix>-outreach qualified-lead '{"company":"Initech","tier":"hot","icp_match":0.91,"contacts":["bill@initech.com"]}'

# On <your-prefix>-crm-sync — subscribe to engagement events:
pilotctl subscribe <your-prefix>-outreach engagement-event

# On <your-prefix>-outreach — publish an engagement event:
pilotctl publish <your-prefix>-crm-sync engagement-event '{"lead":"Initech","event":"reply","sentiment":"positive","next_action":"book_demo"}'

# On <your-prefix>-crm-sync — push to CRM:
pilotctl publish <your-prefix>-crm-sync crm-update '{"deal":"Initech","stage":"demo_scheduled","value":48000,"forecast":"commit"}'
```
