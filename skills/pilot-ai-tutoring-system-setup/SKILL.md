---
name: pilot-ai-tutoring-system-setup
description: >
  Deploy an adaptive AI tutoring system with 3 agents.

  Use this skill when:
  1. User wants to set up a personalized tutoring or e-learning pipeline
  2. User is configuring a content curator, tutor, or assessment agent
  3. User asks about adaptive learning, quiz generation, or curriculum management workflows

  Do NOT use this skill when:
  - User wants a simple chat interface (use pilot-chat instead)
  - User wants to archive files without a learning context (use pilot-archive instead)
tags:
  - pilot-protocol
  - setup
  - education
  - tutoring
  - adaptive-learning
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

# AI Tutoring System Setup

Deploy 3 agents that curate content, deliver lessons, and assess learners in an adaptive feedback loop.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| content-curator | `<prefix>-content-curator` | pilot-archive, pilot-discover, pilot-dataset | Organizes materials, selects content by level |
| tutor | `<prefix>-tutor` | pilot-chat, pilot-task-router, pilot-receipt | Delivers lessons, answers questions, tracks progress |
| assessor | `<prefix>-assessor` | pilot-metrics, pilot-alert, pilot-audit-log | Creates quizzes, grades work, identifies gaps |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For content-curator:
clawhub install pilot-archive pilot-discover pilot-dataset
# For tutor:
clawhub install pilot-chat pilot-task-router pilot-receipt
# For assessor:
clawhub install pilot-metrics pilot-alert pilot-audit-log
```

**Step 3:** Set the hostname and write the manifest:
```bash
pilotctl --json set-hostname <prefix>-<role>
mkdir -p ~/.pilot/setups
```
Then write the role-specific JSON manifest to `~/.pilot/setups/ai-tutoring-system.json`.

**Step 4:** Tell the user to initiate handshakes with adjacent agents.

## Manifest Templates Per Role

### content-curator
```json
{
  "setup": "ai-tutoring-system",
  "setup_name": "AI Tutoring System",
  "role": "content-curator",
  "role_name": "Content Curator",
  "hostname": "<prefix>-content-curator",
  "description": "Organizes learning materials by topic and difficulty, adapts curriculum from gap analysis.",
  "skills": {
    "pilot-archive": "Store and version learning materials by topic and difficulty.",
    "pilot-discover": "Find relevant materials matching a learner's current level.",
    "pilot-dataset": "Maintain the knowledge graph of topics and prerequisites."
  },
  "peers": [
    { "role": "tutor", "hostname": "<prefix>-tutor", "description": "Receives lesson materials" },
    { "role": "assessor", "hostname": "<prefix>-assessor", "description": "Sends gap analysis" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-tutor", "port": 1002, "topic": "lesson-material", "description": "Lesson content and curriculum" },
    { "direction": "receive", "peer": "<prefix>-assessor", "port": 1002, "topic": "gap-analysis", "description": "Knowledge gaps and adaptation signals" }
  ],
  "handshakes_needed": ["<prefix>-tutor", "<prefix>-assessor"]
}
```

### tutor
```json
{
  "setup": "ai-tutoring-system",
  "setup_name": "AI Tutoring System",
  "role": "tutor",
  "role_name": "Tutor Agent",
  "hostname": "<prefix>-tutor",
  "description": "Delivers personalized lessons, answers questions, tracks learner progress.",
  "skills": {
    "pilot-chat": "Interactive lesson delivery and question answering.",
    "pilot-task-router": "Route complex questions to the curator for specialized content.",
    "pilot-receipt": "Confirm lesson completion back to the curator."
  },
  "peers": [
    { "role": "content-curator", "hostname": "<prefix>-content-curator", "description": "Sends lesson materials" },
    { "role": "assessor", "hostname": "<prefix>-assessor", "description": "Receives learner responses" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-content-curator", "port": 1002, "topic": "lesson-material", "description": "Lesson content" },
    { "direction": "send", "peer": "<prefix>-assessor", "port": 1002, "topic": "learner-response", "description": "Learner answers and progress" }
  ],
  "handshakes_needed": ["<prefix>-content-curator", "<prefix>-assessor"]
}
```

### assessor
```json
{
  "setup": "ai-tutoring-system",
  "setup_name": "AI Tutoring System",
  "role": "assessor",
  "role_name": "Assessment Agent",
  "hostname": "<prefix>-assessor",
  "description": "Creates quizzes, grades submissions, identifies knowledge gaps.",
  "skills": {
    "pilot-metrics": "Track learner mastery scores and progress over time.",
    "pilot-alert": "Alert the tutor when a learner is struggling on a topic.",
    "pilot-audit-log": "Log all assessments and grade history for review."
  },
  "peers": [
    { "role": "tutor", "hostname": "<prefix>-tutor", "description": "Sends learner responses" },
    { "role": "content-curator", "hostname": "<prefix>-content-curator", "description": "Receives gap analysis" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-tutor", "port": 1002, "topic": "learner-response", "description": "Learner answers and progress" },
    { "direction": "send", "peer": "<prefix>-content-curator", "port": 1002, "topic": "gap-analysis", "description": "Knowledge gaps and curriculum recommendations" }
  ],
  "handshakes_needed": ["<prefix>-tutor", "<prefix>-content-curator"]
}
```

## Data Flows

- `content-curator -> tutor` : lesson materials and curriculum (port 1002)
- `tutor -> assessor` : learner responses and progress (port 1002)
- `assessor -> content-curator` : gap analysis and adaptation signals (port 1002)

## Handshakes

```bash
# content-curator <-> tutor:
pilotctl --json handshake <prefix>-tutor "setup: ai-tutoring-system"
pilotctl --json handshake <prefix>-content-curator "setup: ai-tutoring-system"
# tutor <-> assessor:
pilotctl --json handshake <prefix>-assessor "setup: ai-tutoring-system"
pilotctl --json handshake <prefix>-tutor "setup: ai-tutoring-system"
# assessor <-> content-curator:
pilotctl --json handshake <prefix>-content-curator "setup: ai-tutoring-system"
pilotctl --json handshake <prefix>-assessor "setup: ai-tutoring-system"
```

## Workflow Example

```bash
# On content-curator -- publish lesson:
pilotctl --json publish <prefix>-tutor lesson-material '{"learner_id":"s-042","topic":"linear-algebra","lesson":"matrices-intro"}'

# On tutor -- publish learner response:
pilotctl --json publish <prefix>-assessor learner-response '{"learner_id":"s-042","answers":[{"q":"det_2x2","correct":true}]}'

# On assessor -- publish gap analysis:
pilotctl --json publish <prefix>-content-curator gap-analysis '{"learner_id":"s-042","mastery":0.67,"gaps":["eigenvalues"]}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
