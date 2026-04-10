# Recruitment Pipeline

Deploy a multi-agent recruitment pipeline that automates candidate sourcing, resume screening, and interview scheduling. Each agent handles a distinct stage of the hiring funnel, passing enriched candidate data downstream until interviews are booked and tracked.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### sourcer (Candidate Sourcer)
Scans job boards, LinkedIn profiles, and referral networks. Packages candidate profiles with match scores.

**Skills:** pilot-discover, pilot-stream-data, pilot-metrics

### screener (Resume Screener)
Evaluates candidates against job requirements, scores skills, flags red flags.

**Skills:** pilot-event-filter, pilot-task-router, pilot-alert

### scheduler (Interview Scheduler)
Coordinates interview slots, sends calendar invites, tracks hiring pipeline status.

**Skills:** pilot-webhook-bridge, pilot-slack-bridge, pilot-receipt

## Data Flow

```
sourcer   --> screener  : Candidate profiles with match scores (port 1002)
screener  --> scheduler : Screened candidates ready for interviews (port 1002)
scheduler --> external  : Interview invites via calendar API (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (candidate sourcer)
clawhub install pilot-discover pilot-stream-data pilot-metrics
pilotctl set-hostname <your-prefix>-sourcer

# On server 2 (resume screener)
clawhub install pilot-event-filter pilot-task-router pilot-alert
pilotctl set-hostname <your-prefix>-screener

# On server 3 (interview scheduler)
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-receipt
pilotctl set-hostname <your-prefix>-scheduler
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On sourcer:
pilotctl handshake <your-prefix>-screener "setup: recruitment-pipeline"
# On screener:
pilotctl handshake <your-prefix>-sourcer "setup: recruitment-pipeline"
# On screener:
pilotctl handshake <your-prefix>-scheduler "setup: recruitment-pipeline"
# On scheduler:
pilotctl handshake <your-prefix>-screener "setup: recruitment-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-screener — subscribe to candidate profiles from sourcer:
pilotctl subscribe <your-prefix>-sourcer candidate-profile

# On <your-prefix>-scheduler — subscribe to screened candidates from screener:
pilotctl subscribe <your-prefix>-screener screened-candidate

# On <your-prefix>-sourcer — publish a candidate profile:
pilotctl publish <your-prefix>-screener candidate-profile '{"candidate":"Jane Doe","role":"Senior Backend Engineer","match_score":92,"source":"linkedin","skills":["Go","Kubernetes","PostgreSQL"]}'

# On <your-prefix>-screener — publish a screened candidate:
pilotctl publish <your-prefix>-scheduler screened-candidate '{"candidate":"Jane Doe","screen_score":88,"red_flags":[],"recommendation":"interview","available_slots":["2026-04-14T10:00Z","2026-04-15T14:00Z"]}'

# On <your-prefix>-scheduler — send an interview invite:
pilotctl publish <your-prefix>-scheduler interview-invite '{"candidate":"Jane Doe","interviewer":"John Smith","slot":"2026-04-14T10:00Z","calendar_link":"https://cal.example.com/abc123"}'
```
