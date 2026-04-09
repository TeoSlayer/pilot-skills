---
name: pilot-ci-cd-pipeline-setup
description: >
  Deploy a decentralized CI/CD pipeline with 3 agents.

  Use this skill when:
  1. User wants to set up a CI/CD pipeline across multiple agents
  2. User is configuring a build, test, or deploy agent
  3. User asks about automated build/test/deploy workflows

  Do NOT use this skill when:
  - User wants to route a single task (use pilot-task-router instead)
  - User wants to share a single file (use pilot-share instead)
tags:
  - pilot-protocol
  - setup
  - ci-cd
  - devops
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

# CI/CD Pipeline Setup

Deploy 3 agents that build, test, and deploy code with zero central server.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| ci-builder | `<prefix>-ci-builder` | pilot-task-router, pilot-share, pilot-github-bridge | Builds code, shares artifacts |
| ci-tester | `<prefix>-ci-tester` | pilot-task-router, pilot-share, pilot-audit-log | Runs tests, logs results |
| ci-deployer | `<prefix>-ci-deployer` | pilot-task-router, pilot-share, pilot-webhook-bridge, pilot-receipt | Deploys, sends receipts |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For ci-builder:
clawhub install pilot-task-router pilot-share pilot-github-bridge
# For ci-tester:
clawhub install pilot-task-router pilot-share pilot-audit-log
# For ci-deployer:
clawhub install pilot-task-router pilot-share pilot-webhook-bridge pilot-receipt
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
```
Then write the role-specific JSON manifest to `~/.pilot/setups/ci-cd-pipeline.json`.

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### ci-builder
```json
{
  "setup": "ci-cd-pipeline",
  "setup_name": "CI/CD Pipeline",
  "role": "ci-builder",
  "role_name": "Build Agent",
  "hostname": "<prefix>-ci-builder",
  "description": "Listens for GitHub push/PR webhooks, clones the repo, runs builds, and shares artifacts with the test agent.",
  "skills": {
    "pilot-task-router": "Accept build requests and route artifacts to ci-tester.",
    "pilot-share": "Send build artifacts (tarballs, binaries) to ci-tester.",
    "pilot-github-bridge": "Listen for GitHub webhooks (push, PR) to trigger builds."
  },
  "peers": [
    { "role": "ci-tester", "hostname": "<prefix>-ci-tester", "description": "Receives build artifacts for testing" },
    { "role": "ci-deployer", "hostname": "<prefix>-ci-deployer", "description": "Receives deployment receipt" }
  ],
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-ci-tester", "port": 1001, "topic": "build-ready", "description": "Build artifacts and test instructions" },
    { "direction": "receive", "peer": "<prefix>-ci-deployer", "port": 1002, "topic": "deploy-receipt", "description": "Deployment confirmation" }
  ],
  "handshakes_needed": ["<prefix>-ci-tester", "<prefix>-ci-deployer"]
}
```

### ci-tester
```json
{
  "setup": "ci-cd-pipeline",
  "setup_name": "CI/CD Pipeline",
  "role": "ci-tester",
  "role_name": "Test Agent",
  "hostname": "<prefix>-ci-tester",
  "description": "Receives build artifacts, runs test suites, and logs results. Passes successful builds to the deployer.",
  "skills": {
    "pilot-task-router": "Accept test tasks from ci-builder and forward passing builds to ci-deployer.",
    "pilot-share": "Receive artifacts from ci-builder, send tested artifacts to ci-deployer.",
    "pilot-audit-log": "Log all test runs with pass/fail results and coverage."
  },
  "peers": [
    { "role": "ci-builder", "hostname": "<prefix>-ci-builder", "description": "Sends build artifacts" },
    { "role": "ci-deployer", "hostname": "<prefix>-ci-deployer", "description": "Receives tested artifacts" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-ci-builder", "port": 1001, "topic": "build-ready", "description": "Build artifacts" },
    { "direction": "send", "peer": "<prefix>-ci-deployer", "port": 1001, "topic": "tests-passed", "description": "Tested artifacts with report" }
  ],
  "handshakes_needed": ["<prefix>-ci-builder", "<prefix>-ci-deployer"]
}
```

### ci-deployer
```json
{
  "setup": "ci-cd-pipeline",
  "setup_name": "CI/CD Pipeline",
  "role": "ci-deployer",
  "role_name": "Deploy Agent",
  "hostname": "<prefix>-ci-deployer",
  "description": "Receives tested artifacts, deploys to production, sends deployment receipts, and triggers post-deploy webhooks.",
  "skills": {
    "pilot-task-router": "Accept deploy tasks from ci-tester.",
    "pilot-share": "Receive tested artifacts from ci-tester.",
    "pilot-webhook-bridge": "Trigger post-deploy webhooks (Slack, monitoring).",
    "pilot-receipt": "Send deployment receipts back to ci-builder."
  },
  "peers": [
    { "role": "ci-builder", "hostname": "<prefix>-ci-builder", "description": "Receives deployment receipt" },
    { "role": "ci-tester", "hostname": "<prefix>-ci-tester", "description": "Sends tested artifacts" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-ci-tester", "port": 1001, "topic": "tests-passed", "description": "Tested artifacts" },
    { "direction": "send", "peer": "<prefix>-ci-builder", "port": 1002, "topic": "deploy-receipt", "description": "Deployment confirmation" }
  ],
  "handshakes_needed": ["<prefix>-ci-builder", "<prefix>-ci-tester"]
}
```

## Data Flows

- `ci-builder → ci-tester` : build artifacts (port 1001)
- `ci-tester → ci-deployer` : tested artifacts with test report (port 1001)
- `ci-deployer → ci-builder` : deployment receipt (port 1002)

## Handshakes

```bash
# All three agents handshake each other:
pilotctl --json handshake <prefix>-ci-tester "setup: ci-cd-pipeline"
pilotctl --json handshake <prefix>-ci-deployer "setup: ci-cd-pipeline"
pilotctl --json handshake <prefix>-ci-builder "setup: ci-cd-pipeline"
```

## Workflow Example

```bash
# On ci-builder — send build artifact:
pilotctl --json send-file <prefix>-ci-tester ./build/app-v2.3.tar.gz
pilotctl --json publish <prefix>-ci-tester build-ready '{"commit":"a1b2c3d","branch":"main"}'

# On ci-tester — forward to deployer:
pilotctl --json send-file <prefix>-ci-deployer ./build/app-v2.3.tar.gz
pilotctl --json publish <prefix>-ci-deployer tests-passed '{"commit":"a1b2c3d","tests":142,"passed":142}'

# On ci-deployer — send receipt:
pilotctl --json publish <prefix>-ci-builder deploy-receipt '{"commit":"a1b2c3d","status":"success"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
