---
name: pilot-dev-team-assistants-setup
description: >
  Deploy a dev team assistant system with 4 agents.

  Use this skill when:
  1. User wants to automate code review, testing, and docs for PRs
  2. User is configuring a reviewer, test runner, doc writer, or coordinator agent
  3. User asks about automating the PR workflow across multiple agents

  Do NOT use this skill when:
  - User wants a single code review (use pilot-review instead)
  - User wants to run tests once (use pilot-task-router instead)
tags:
  - pilot-protocol
  - setup
  - dev-team
  - code-review
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

# Dev Team Assistants Setup

Deploy 4 agents that automate the PR workflow: review, test, docs, and coordination.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| reviewer | `<prefix>-reviewer` | pilot-github-bridge, pilot-review, pilot-chat | Reviews PR diffs for quality |
| test-runner | `<prefix>-test-runner` | pilot-github-bridge, pilot-task-router, pilot-audit-log | Runs test suites |
| doc-writer | `<prefix>-doc-writer` | pilot-github-bridge, pilot-share, pilot-task-router | Generates docs |
| coordinator | `<prefix>-coordinator` | pilot-github-bridge, pilot-task-chain, pilot-slack-bridge, pilot-broadcast | Orchestrates and summarizes |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# reviewer:
clawhub install pilot-github-bridge pilot-review pilot-chat
# test-runner:
clawhub install pilot-github-bridge pilot-task-router pilot-audit-log
# doc-writer:
clawhub install pilot-github-bridge pilot-share pilot-task-router
# coordinator:
clawhub install pilot-github-bridge pilot-task-chain pilot-slack-bridge pilot-broadcast
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/dev-team-assistants.json`.

**Step 4:** Handshake with coordinator (all agents handshake the coordinator).

## Manifest Templates Per Role

### coordinator
```json
{
  "setup": "dev-team-assistants", "role": "coordinator", "role_name": "PR Coordinator",
  "hostname": "<prefix>-coordinator",
  "skills": {
    "pilot-github-bridge": "Watch GitHub for new PRs, post unified summary comments.",
    "pilot-task-chain": "Fan out review/test/doc tasks and collect results.",
    "pilot-slack-bridge": "Post PR status updates to Slack.",
    "pilot-broadcast": "Broadcast new PR notifications to all assistants."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-reviewer", "port": 1002, "topic": "pr-review", "description": "PR details for review" },
    { "direction": "send", "peer": "<prefix>-test-runner", "port": 1002, "topic": "pr-test", "description": "PR details for testing" },
    { "direction": "send", "peer": "<prefix>-doc-writer", "port": 1002, "topic": "pr-docs", "description": "PR details for docs" },
    { "direction": "receive", "peer": "<prefix>-reviewer", "port": 1002, "topic": "review-result", "description": "Review findings" },
    { "direction": "receive", "peer": "<prefix>-test-runner", "port": 1002, "topic": "test-result", "description": "Test results" },
    { "direction": "receive", "peer": "<prefix>-doc-writer", "port": 1001, "topic": "docs-result", "description": "Generated docs" }
  ],
  "handshakes_needed": ["<prefix>-reviewer", "<prefix>-test-runner", "<prefix>-doc-writer"]
}
```

### reviewer
```json
{
  "setup": "dev-team-assistants", "role": "reviewer", "role_name": "Code Reviewer",
  "hostname": "<prefix>-reviewer",
  "skills": {
    "pilot-github-bridge": "Fetch PR diffs from GitHub.",
    "pilot-review": "Analyze code for quality, security, and style issues.",
    "pilot-chat": "Discuss review findings with coordinator."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-coordinator", "port": 1002, "topic": "pr-review", "description": "PR details" },
    { "direction": "send", "peer": "<prefix>-coordinator", "port": 1002, "topic": "review-result", "description": "Review findings" }
  ],
  "handshakes_needed": ["<prefix>-coordinator"]
}
```

## Data Flows

- `coordinator → reviewer/test-runner/doc-writer` : PR details (port 1002)
- `reviewer/test-runner → coordinator` : results (port 1002)
- `doc-writer → coordinator` : generated docs (port 1001)

## Workflow Example

```bash
# On coordinator — fan out:
pilotctl --json task submit <prefix>-reviewer --task '{"pr":1234,"repo":"acme/api","action":"review"}'
pilotctl --json task submit <prefix>-test-runner --task '{"pr":1234,"action":"test","branch":"feature/auth"}'
# On reviewer — return:
pilotctl --json publish <prefix>-coordinator review-result '{"pr":1234,"issues":2,"approval":"changes_requested"}'
# On test-runner — return:
pilotctl --json publish <prefix>-coordinator test-result '{"pr":1234,"passed":89,"failed":0,"coverage":82}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
