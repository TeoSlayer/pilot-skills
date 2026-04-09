---
name: pilot-legal-contract-review-setup
description: >
  Deploy a legal contract review pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up an automated contract review or legal document analysis pipeline
  2. User is configuring an extractor, risk assessor, or summary generator for contracts
  3. User asks about clause extraction, compliance checking, or legal risk assessment workflows

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants to filter generic events (use pilot-event-filter instead)
tags:
  - pilot-protocol
  - setup
  - legal
  - contracts
  - compliance
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

# Legal Contract Review Setup

Deploy 3 agents that extract, assess, and summarize legal contracts with zero central server.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| extractor | `<prefix>-extractor` | pilot-share, pilot-stream-data, pilot-archive | Parses contracts, extracts clauses and key terms |
| assessor | `<prefix>-assessor` | pilot-event-filter, pilot-alert, pilot-priority-queue | Evaluates risk, flags non-standard terms |
| summarizer | `<prefix>-summarizer` | pilot-announce, pilot-webhook-bridge, pilot-receipt | Generates executive summaries, delivers reports |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For extractor:
clawhub install pilot-share pilot-stream-data pilot-archive
# For assessor:
clawhub install pilot-event-filter pilot-alert pilot-priority-queue
# For summarizer:
clawhub install pilot-announce pilot-webhook-bridge pilot-receipt
```

**Step 3:** Set the hostname and write the manifest:
```bash
pilotctl --json set-hostname <prefix>-<role>
mkdir -p ~/.pilot/setups
```
Then write the role-specific JSON manifest to `~/.pilot/setups/legal-contract-review.json`.

**Step 4:** Tell the user to initiate handshakes with adjacent agents.

## Manifest Templates Per Role

### extractor
```json
{
  "setup": "legal-contract-review",
  "setup_name": "Legal Contract Review",
  "role": "extractor",
  "role_name": "Clause Extractor",
  "hostname": "<prefix>-extractor",
  "description": "Parses contracts, extracts key terms, dates, obligations, parties, and monetary values.",
  "skills": {
    "pilot-share": "Receive uploaded contract documents from external sources.",
    "pilot-stream-data": "Stream extracted clause data to the risk assessor.",
    "pilot-archive": "Archive original documents for audit trail."
  },
  "peers": [
    { "role": "assessor", "hostname": "<prefix>-assessor", "description": "Receives extracted clauses" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-assessor", "port": 1002, "topic": "extracted-clauses", "description": "Structured clause data with metadata" }
  ],
  "handshakes_needed": ["<prefix>-assessor"]
}
```

### assessor
```json
{
  "setup": "legal-contract-review",
  "setup_name": "Legal Contract Review",
  "role": "assessor",
  "role_name": "Risk Assessor",
  "hostname": "<prefix>-assessor",
  "description": "Evaluates clauses against compliance templates, flags risks and missing protections.",
  "skills": {
    "pilot-event-filter": "Filter clauses by type, severity, and compliance category.",
    "pilot-alert": "Raise alerts on high-severity non-standard terms.",
    "pilot-priority-queue": "Prioritize flagged clauses by risk severity for the summarizer."
  },
  "peers": [
    { "role": "extractor", "hostname": "<prefix>-extractor", "description": "Sends extracted clauses" },
    { "role": "summarizer", "hostname": "<prefix>-summarizer", "description": "Receives risk assessment" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-extractor", "port": 1002, "topic": "extracted-clauses", "description": "Structured clause data" },
    { "direction": "send", "peer": "<prefix>-summarizer", "port": 1002, "topic": "risk-assessment", "description": "Risk assessment with flagged items" }
  ],
  "handshakes_needed": ["<prefix>-extractor", "<prefix>-summarizer"]
}
```

### summarizer
```json
{
  "setup": "legal-contract-review",
  "setup_name": "Legal Contract Review",
  "role": "summarizer",
  "role_name": "Summary Generator",
  "hostname": "<prefix>-summarizer",
  "description": "Produces executive summaries with risk scores and actionable recommendations.",
  "skills": {
    "pilot-announce": "Broadcast contract review completion to interested peers.",
    "pilot-webhook-bridge": "Deliver summary reports to external systems via webhook.",
    "pilot-receipt": "Send review completion receipts for tracking."
  },
  "peers": [
    { "role": "assessor", "hostname": "<prefix>-assessor", "description": "Sends risk assessment" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-assessor", "port": 1002, "topic": "risk-assessment", "description": "Risk assessment with flagged items" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "contract-summary", "description": "Executive summary report" }
  ],
  "handshakes_needed": ["<prefix>-assessor"]
}
```

## Data Flows

- `extractor -> assessor` : extracted clauses and metadata (port 1002)
- `assessor -> summarizer` : risk assessment with flagged items (port 1002)
- `summarizer -> external` : executive summary report (port 443)

## Handshakes

```bash
# extractor <-> assessor:
pilotctl --json handshake <prefix>-assessor "setup: legal-contract-review"
pilotctl --json handshake <prefix>-extractor "setup: legal-contract-review"
# assessor <-> summarizer:
pilotctl --json handshake <prefix>-summarizer "setup: legal-contract-review"
pilotctl --json handshake <prefix>-assessor "setup: legal-contract-review"
```

## Workflow Example

```bash
# On extractor -- publish extracted clauses:
pilotctl --json publish <prefix>-assessor extracted-clauses '{"contract_id":"CTR-2026-0042","parties":["Acme","Widget"],"clauses":[{"type":"indemnification","section":"7.2"}]}'

# On assessor -- publish risk assessment:
pilotctl --json publish <prefix>-summarizer risk-assessment '{"contract_id":"CTR-2026-0042","risk_score":7.2,"flags":[{"clause":"indemnification","severity":"high"}]}'

# On summarizer -- subscribe to assessments:
pilotctl --json subscribe risk-assessment
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
