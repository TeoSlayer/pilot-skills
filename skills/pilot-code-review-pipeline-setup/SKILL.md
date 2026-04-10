---
name: pilot-code-review-pipeline-setup
description: >
  Deploy an automated code review pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up an automated code review or PR analysis pipeline
  2. User is configuring an agent as part of a code review workflow
  3. User asks about scanning PRs, reviewing code quality, or reporting review results across agents

  Do NOT use this skill when:
  - User wants a single static analysis run (use pilot-task-router instead)
  - User wants to send a one-off alert (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - code-review
  - ci-cd
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

# Code Review Pipeline Setup

Deploy 3 agents that scan PRs, analyze code quality, and report review results.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| scanner | `<prefix>-scanner` | pilot-github-bridge, pilot-task-router, pilot-metrics | Runs static analysis and security scans on PRs |
| reviewer | `<prefix>-reviewer` | pilot-event-filter, pilot-alert, pilot-audit-log | Analyzes scan results, suggests improvements |
| reporter | `<prefix>-reporter` | pilot-webhook-bridge, pilot-slack-bridge, pilot-receipt | Posts PR comments, sends notifications |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For scanner:
clawhub install pilot-github-bridge pilot-task-router pilot-metrics

# For reviewer:
clawhub install pilot-event-filter pilot-alert pilot-audit-log

# For reporter:
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-receipt
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/code-review-pipeline.json << 'MANIFEST'
{
  "setup": "code-review-pipeline",
  "setup_name": "Code Review Pipeline",
  "role": "<ROLE_ID>",
  "role_name": "<ROLE_NAME>",
  "hostname": "<prefix>-<role>",
  "description": "<ROLE_DESCRIPTION>",
  "skills": { "<skill>": "<contextual description>" },
  "peers": [ { "role": "...", "hostname": "...", "description": "..." } ],
  "data_flows": [ { "direction": "send|receive", "peer": "...", "port": 1002, "topic": "...", "description": "..." } ],
  "handshakes_needed": [ "<peer-hostname>" ]
}
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### scanner
```json
{
  "setup": "code-review-pipeline", "setup_name": "Code Review Pipeline",
  "role": "scanner", "role_name": "Code Scanner",
  "hostname": "<prefix>-scanner",
  "description": "Runs static analysis, linting, and security scans on PRs.",
  "skills": {
    "pilot-github-bridge": "Watch for new PRs, fetch diffs and changed files for scanning.",
    "pilot-task-router": "Route scan tasks across analysis tools and collect results.",
    "pilot-metrics": "Track scan counts, finding severity distribution, and scan duration."
  },
  "peers": [
    { "role": "reviewer", "hostname": "<prefix>-reviewer", "description": "Receives scan results for code analysis" },
    { "role": "reporter", "hostname": "<prefix>-reporter", "description": "Final stage — does not communicate directly" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-reviewer", "port": 1002, "topic": "scan-result", "description": "Scan results with findings and severity" }
  ],
  "handshakes_needed": ["<prefix>-reviewer"]
}
```

### reviewer
```json
{
  "setup": "code-review-pipeline", "setup_name": "Code Review Pipeline",
  "role": "reviewer", "role_name": "Code Reviewer",
  "hostname": "<prefix>-reviewer",
  "description": "Analyzes scan results, checks code patterns, suggests improvements.",
  "skills": {
    "pilot-event-filter": "Filter scan results by severity and relevance before analysis.",
    "pilot-alert": "Flag critical findings that need immediate attention.",
    "pilot-audit-log": "Log all review decisions for compliance and traceability."
  },
  "peers": [
    { "role": "scanner", "hostname": "<prefix>-scanner", "description": "Sends scan results from PR analysis" },
    { "role": "reporter", "hostname": "<prefix>-reporter", "description": "Receives review verdicts for reporting" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-scanner", "port": 1002, "topic": "scan-result", "description": "Scan results with findings and severity" },
    { "direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "review-verdict", "description": "Review verdict with suggestions and approval status" }
  ],
  "handshakes_needed": ["<prefix>-scanner", "<prefix>-reporter"]
}
```

### reporter
```json
{
  "setup": "code-review-pipeline", "setup_name": "Code Review Pipeline",
  "role": "reporter", "role_name": "Review Reporter",
  "hostname": "<prefix>-reporter",
  "description": "Formats review results, posts PR comments, tracks metrics.",
  "skills": {
    "pilot-webhook-bridge": "Post review comments to GitHub PRs via webhook.",
    "pilot-slack-bridge": "Send review summaries to Slack channels.",
    "pilot-receipt": "Confirm delivery of review notifications to external systems."
  },
  "peers": [
    { "role": "scanner", "hostname": "<prefix>-scanner", "description": "First stage — does not communicate directly" },
    { "role": "reviewer", "hostname": "<prefix>-reviewer", "description": "Sends review verdicts for reporting" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-reviewer", "port": 1002, "topic": "review-verdict", "description": "Review verdict with suggestions and approval status" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "review-notification", "description": "Review notification posted to PR and Slack" }
  ],
  "handshakes_needed": ["<prefix>-reviewer"]
}
```

## Data Flows

- `scanner -> reviewer` : scan-result events (port 1002)
- `reviewer -> reporter` : review-verdict events (port 1002)
- `reporter -> external` : review-notification via webhook (port 443)

## Handshakes

```bash
# scanner and reviewer handshake with each other:
pilotctl --json handshake <prefix>-reviewer "setup: code-review-pipeline"
pilotctl --json handshake <prefix>-scanner "setup: code-review-pipeline"

# reviewer and reporter handshake with each other:
pilotctl --json handshake <prefix>-reporter "setup: code-review-pipeline"
pilotctl --json handshake <prefix>-reviewer "setup: code-review-pipeline"
```

## Workflow Example

```bash
# On reviewer — subscribe to scan results:
pilotctl --json subscribe <prefix>-scanner scan-result

# On reporter — subscribe to review verdicts:
pilotctl --json subscribe <prefix>-reviewer review-verdict

# On scanner — publish a scan result:
pilotctl --json publish <prefix>-reviewer scan-result '{"pr":142,"repo":"acme/api","findings":[{"file":"auth.go","line":58,"severity":"high","rule":"sql-injection"}]}'

# On reviewer — publish a review verdict:
pilotctl --json publish <prefix>-reporter review-verdict '{"pr":142,"status":"changes_requested","comments":1}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
