---
name: pilot-recruitment-pipeline-setup
description: >
  Deploy a recruitment pipeline with 3 agents for candidate sourcing, screening, and interview scheduling.

  Use this skill when:
  1. User wants to set up a recruitment or hiring pipeline
  2. User is configuring an agent as part of a recruitment automation setup
  3. User asks about candidate sourcing, resume screening, or interview scheduling across agents

  Do NOT use this skill when:
  - User wants to discover a single service (use pilot-discover instead)
  - User wants to send a one-off alert (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - recruitment
  - hiring
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

# Recruitment Pipeline Setup

Deploy 3 agents that automate candidate sourcing, resume screening, and interview scheduling.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| sourcer | `<prefix>-sourcer` | pilot-discover, pilot-stream-data, pilot-metrics | Scans job boards and referral networks, publishes candidate profiles |
| screener | `<prefix>-screener` | pilot-event-filter, pilot-task-router, pilot-alert | Evaluates candidates, scores skills, flags red flags |
| scheduler | `<prefix>-scheduler` | pilot-webhook-bridge, pilot-slack-bridge, pilot-receipt | Coordinates interviews, sends invites, tracks pipeline |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For sourcer:
clawhub install pilot-discover pilot-stream-data pilot-metrics
# For screener:
clawhub install pilot-event-filter pilot-task-router pilot-alert
# For scheduler:
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-receipt
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/recruitment-pipeline.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### sourcer
```json
{
  "setup": "recruitment-pipeline", "setup_name": "Recruitment Pipeline",
  "role": "sourcer", "role_name": "Candidate Sourcer",
  "hostname": "<prefix>-sourcer",
  "description": "Scans job boards, LinkedIn profiles, and referral networks. Packages candidate profiles with match scores.",
  "skills": {
    "pilot-discover": "Search job boards and LinkedIn for candidates matching open roles.",
    "pilot-stream-data": "Stream candidate profiles to screener as they are found.",
    "pilot-metrics": "Track sourcing metrics: candidates found, match scores, source breakdown."
  },
  "peers": [
    {"role": "screener", "hostname": "<prefix>-screener", "description": "Receives candidate profiles for screening"},
    {"role": "scheduler", "hostname": "<prefix>-scheduler", "description": "Downstream — does not communicate directly"}
  ],
  "data_flows": [
    {"direction": "send", "peer": "<prefix>-screener", "port": 1002, "topic": "candidate-profile", "description": "Candidate profiles with match scores"}
  ],
  "handshakes_needed": ["<prefix>-screener"]
}
```

### screener
```json
{
  "setup": "recruitment-pipeline", "setup_name": "Recruitment Pipeline",
  "role": "screener", "role_name": "Resume Screener",
  "hostname": "<prefix>-screener",
  "description": "Evaluates candidates against job requirements, scores skills, flags red flags.",
  "skills": {
    "pilot-event-filter": "Filter candidates below threshold scores or with disqualifying criteria.",
    "pilot-task-router": "Route screened candidates to appropriate interview tracks.",
    "pilot-alert": "Alert hiring managers when high-priority candidates are identified."
  },
  "peers": [
    {"role": "sourcer", "hostname": "<prefix>-sourcer", "description": "Sends candidate profiles for screening"},
    {"role": "scheduler", "hostname": "<prefix>-scheduler", "description": "Receives screened candidates for interview scheduling"}
  ],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-sourcer", "port": 1002, "topic": "candidate-profile", "description": "Candidate profiles with match scores"},
    {"direction": "send", "peer": "<prefix>-scheduler", "port": 1002, "topic": "screened-candidate", "description": "Screened candidates ready for interviews"}
  ],
  "handshakes_needed": ["<prefix>-sourcer", "<prefix>-scheduler"]
}
```

### scheduler
```json
{
  "setup": "recruitment-pipeline", "setup_name": "Recruitment Pipeline",
  "role": "scheduler", "role_name": "Interview Scheduler",
  "hostname": "<prefix>-scheduler",
  "description": "Coordinates interview slots, sends calendar invites, tracks hiring pipeline status.",
  "skills": {
    "pilot-webhook-bridge": "Send interview invites via calendar API webhooks.",
    "pilot-slack-bridge": "Notify hiring channels when interviews are booked or completed.",
    "pilot-receipt": "Track interview confirmations and candidate responses."
  },
  "peers": [
    {"role": "sourcer", "hostname": "<prefix>-sourcer", "description": "Upstream — does not communicate directly"},
    {"role": "screener", "hostname": "<prefix>-screener", "description": "Sends screened candidates for scheduling"}
  ],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-screener", "port": 1002, "topic": "screened-candidate", "description": "Screened candidates ready for interviews"},
    {"direction": "send", "peer": "external", "port": 443, "topic": "interview-invite", "description": "Interview invites via calendar API"}
  ],
  "handshakes_needed": ["<prefix>-screener"]
}
```

## Data Flows

- `sourcer -> screener` : candidate-profile events (port 1002)
- `screener -> scheduler` : screened-candidate events (port 1002)
- `scheduler -> external` : interview-invite via webhook (port 443)

## Handshakes

```bash
# sourcer and screener handshake with each other:
pilotctl --json handshake <prefix>-screener "setup: recruitment-pipeline"
pilotctl --json handshake <prefix>-sourcer "setup: recruitment-pipeline"
# screener and scheduler handshake with each other:
pilotctl --json handshake <prefix>-scheduler "setup: recruitment-pipeline"
pilotctl --json handshake <prefix>-screener "setup: recruitment-pipeline"
```

## Workflow Example

```bash
# On screener — subscribe to candidate profiles:
pilotctl --json subscribe <prefix>-sourcer candidate-profile
# On scheduler — subscribe to screened candidates:
pilotctl --json subscribe <prefix>-screener screened-candidate
# On sourcer — publish a candidate profile:
pilotctl --json publish <prefix>-screener candidate-profile '{"candidate":"Jane Doe","role":"Senior Backend Engineer","match_score":92,"source":"linkedin"}'
# On screener — publish a screened candidate:
pilotctl --json publish <prefix>-scheduler screened-candidate '{"candidate":"Jane Doe","screen_score":88,"red_flags":[],"recommendation":"interview"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
