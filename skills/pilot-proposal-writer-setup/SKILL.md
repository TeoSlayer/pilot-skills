---
name: pilot-proposal-writer-setup
description: >
  Deploy a multi-agent proposal writing system with 3 agents.

  Use this skill when:
  1. User wants to set up a proposal writing or RFP response pipeline
  2. User is configuring an agent as part of a proposal drafting workflow
  3. User asks about research briefs, proposal sections, or compliance review across agents

  Do NOT use this skill when:
  - User wants to share a single document (use pilot-share instead)
  - User wants a one-off review (use pilot-review instead)
tags:
  - pilot-protocol
  - setup
  - proposal
  - writing
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

# Proposal Writer Setup

Deploy 3 agents that research RFP requirements, draft proposals, and review for compliance.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| researcher | `<prefix>-researcher` | pilot-discover, pilot-dataset, pilot-archive | Gathers RFP requirements, competitor analysis, client background |
| drafter | `<prefix>-drafter` | pilot-task-router, pilot-share, pilot-receipt | Writes executive summary, technical approach, pricing, timeline |
| reviewer | `<prefix>-reviewer` | pilot-review, pilot-webhook-bridge, pilot-slack-bridge | Reviews for compliance and win themes, formats final submission |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For researcher:
clawhub install pilot-discover pilot-dataset pilot-archive

# For drafter:
clawhub install pilot-task-router pilot-share pilot-receipt

# For reviewer:
clawhub install pilot-review pilot-webhook-bridge pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/proposal-writer.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### researcher
```json
{
  "setup": "proposal-writer", "setup_name": "Proposal Writer",
  "role": "researcher", "role_name": "Proposal Researcher",
  "hostname": "<prefix>-researcher",
  "description": "Gathers RFP requirements, competitor analysis, and client background.",
  "skills": {
    "pilot-discover": "Search for RFP documents, competitor proposals, and market data.",
    "pilot-dataset": "Store structured research briefs and compliance checklists.",
    "pilot-archive": "Archive past proposals and research for reuse."
  },
  "peers": [
    { "role": "drafter", "hostname": "<prefix>-drafter", "description": "Receives research briefs for proposal drafting" },
    { "role": "reviewer", "hostname": "<prefix>-reviewer", "description": "Final stage — does not communicate directly" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-drafter", "port": 1002, "topic": "research-brief", "description": "Research brief with RFP analysis and client context" }
  ],
  "handshakes_needed": ["<prefix>-drafter"]
}
```

### drafter
```json
{
  "setup": "proposal-writer", "setup_name": "Proposal Writer",
  "role": "drafter", "role_name": "Proposal Drafter",
  "hostname": "<prefix>-drafter",
  "description": "Writes proposal sections — executive summary, technical approach, pricing, timeline.",
  "skills": {
    "pilot-task-router": "Route writing tasks across proposal sections and templates.",
    "pilot-share": "Share draft sections with reviewer for compliance check.",
    "pilot-receipt": "Confirm receipt of research briefs from researcher."
  },
  "peers": [
    { "role": "researcher", "hostname": "<prefix>-researcher", "description": "Sends research briefs with RFP analysis" },
    { "role": "reviewer", "hostname": "<prefix>-reviewer", "description": "Receives draft proposals for review" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-researcher", "port": 1002, "topic": "research-brief", "description": "Research brief with RFP analysis and client context" },
    { "direction": "send", "peer": "<prefix>-reviewer", "port": 1002, "topic": "draft-proposal", "description": "Draft proposal with sections and pricing" }
  ],
  "handshakes_needed": ["<prefix>-researcher", "<prefix>-reviewer"]
}
```

### reviewer
```json
{
  "setup": "proposal-writer", "setup_name": "Proposal Writer",
  "role": "reviewer", "role_name": "Proposal Reviewer",
  "hostname": "<prefix>-reviewer",
  "description": "Reviews drafts for compliance, consistency, and win themes. Formats final submission.",
  "skills": {
    "pilot-review": "Check proposal against RFP requirements and scoring criteria.",
    "pilot-webhook-bridge": "Submit final proposals to client portals via webhook.",
    "pilot-slack-bridge": "Notify team of review status and submission confirmation."
  },
  "peers": [
    { "role": "researcher", "hostname": "<prefix>-researcher", "description": "First stage — does not communicate directly" },
    { "role": "drafter", "hostname": "<prefix>-drafter", "description": "Sends draft proposals for review" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-drafter", "port": 1002, "topic": "draft-proposal", "description": "Draft proposal with sections and pricing" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "final-proposal", "description": "Final proposal submission via webhook" }
  ],
  "handshakes_needed": ["<prefix>-drafter"]
}
```

## Data Flows

- `researcher -> drafter` : research-brief events (port 1002)
- `drafter -> reviewer` : draft-proposal events (port 1002)
- `reviewer -> external` : final-proposal via webhook (port 443)

## Handshakes

```bash
# researcher and drafter handshake with each other:
pilotctl --json handshake <prefix>-drafter "setup: proposal-writer"
pilotctl --json handshake <prefix>-researcher "setup: proposal-writer"

# drafter and reviewer handshake with each other:
pilotctl --json handshake <prefix>-reviewer "setup: proposal-writer"
pilotctl --json handshake <prefix>-drafter "setup: proposal-writer"
```

## Workflow Example

```bash
# On drafter — subscribe to research briefs:
pilotctl --json subscribe <prefix>-researcher research-brief

# On reviewer — subscribe to draft proposals:
pilotctl --json subscribe <prefix>-drafter draft-proposal

# On researcher — publish a research brief:
pilotctl --json publish <prefix>-drafter research-brief '{"rfp_id":"RFP-2026-042","client":"Acme Corp","requirements":["cloud migration","SOC2"]}'

# On drafter — publish a draft proposal:
pilotctl --json publish <prefix>-reviewer draft-proposal '{"rfp_id":"RFP-2026-042","sections":{"executive_summary":"We propose...","pricing":"$750K"}}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
