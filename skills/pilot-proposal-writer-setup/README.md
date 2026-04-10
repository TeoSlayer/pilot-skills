# Proposal Writer

Deploy a multi-agent proposal writing system with 3 agents that research RFP requirements and competitor landscape, draft proposal sections with pricing and timelines, and review drafts for compliance and win themes. Each agent handles a stage of the proposal lifecycle -- research, drafting, and review -- so proposals are thorough, consistent, and submission-ready.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### researcher (Proposal Researcher)
Gathers RFP requirements, competitor analysis, and client background. Structures research briefs with key themes and compliance checkpoints.

**Skills:** pilot-discover, pilot-dataset, pilot-archive

### drafter (Proposal Drafter)
Writes proposal sections -- executive summary, technical approach, pricing, timeline. Maintains consistent tone and ensures all RFP requirements are addressed.

**Skills:** pilot-task-router, pilot-share, pilot-receipt

### reviewer (Proposal Reviewer)
Reviews drafts for compliance, consistency, and win themes. Formats final submission with proper structure and branding.

**Skills:** pilot-review, pilot-webhook-bridge, pilot-slack-bridge

## Data Flow

```
researcher --> drafter  : Research brief with RFP analysis and client context (port 1002)
drafter    --> reviewer : Draft proposal with sections and pricing (port 1002)
reviewer   --> external : Final proposal submission via webhook (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (proposal researcher)
clawhub install pilot-discover pilot-dataset pilot-archive
pilotctl set-hostname <your-prefix>-researcher

# On server 2 (proposal drafter)
clawhub install pilot-task-router pilot-share pilot-receipt
pilotctl set-hostname <your-prefix>-drafter

# On server 3 (proposal reviewer)
clawhub install pilot-review pilot-webhook-bridge pilot-slack-bridge
pilotctl set-hostname <your-prefix>-reviewer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On drafter:
pilotctl handshake <your-prefix>-researcher "setup: proposal-writer"
# On researcher:
pilotctl handshake <your-prefix>-drafter "setup: proposal-writer"
# On reviewer:
pilotctl handshake <your-prefix>-drafter "setup: proposal-writer"
# On drafter:
pilotctl handshake <your-prefix>-reviewer "setup: proposal-writer"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-drafter — subscribe to research briefs from researcher:
pilotctl subscribe <your-prefix>-researcher research-brief

# On <your-prefix>-reviewer — subscribe to draft proposals from drafter:
pilotctl subscribe <your-prefix>-drafter draft-proposal

# On <your-prefix>-researcher — publish a research brief:
pilotctl publish <your-prefix>-drafter research-brief '{"rfp_id":"RFP-2026-042","client":"Acme Corp","requirements":["cloud migration","24/7 support","SOC2 compliance"],"competitors":["RivalCo","BigTech Inc"],"budget_range":"$500K-$1M","deadline":"2026-05-15"}'

# On <your-prefix>-drafter — publish a draft proposal:
pilotctl publish <your-prefix>-reviewer draft-proposal '{"rfp_id":"RFP-2026-042","sections":{"executive_summary":"We propose a phased cloud migration...","technical_approach":"Using containerized microservices...","pricing":"$750,000 over 18 months","timeline":"3 phases across 18 months"},"compliance_checklist":["SOC2","24/7 support"]}'

# The reviewer receives the draft and submits:
pilotctl publish <your-prefix>-reviewer final-proposal '{"rfp_id":"RFP-2026-042","status":"approved","score":92,"notes":"Strong technical approach, competitive pricing","submission_url":"https://portal.acme.com/submit"}'
```
