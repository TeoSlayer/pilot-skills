---
name: pilot-quality-assurance-pipeline-setup
description: >
  Deploy a quality assurance pipeline with 3 agents that automate
  test generation, execution, and reporting.

  Use this skill when:
  1. User wants to set up an automated QA or testing pipeline
  2. User is configuring an agent as part of a test automation workflow
  3. User asks about automating test generation, execution, or quality reporting across agents

  Do NOT use this skill when:
  - User wants to run a single test suite (use pilot-task-parallel instead)
  - User wants a one-off alert notification (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - testing
  - qa
  - quality-assurance
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

# Quality Assurance Pipeline Setup

Deploy 3 agents that automate the QA cycle from test generation through execution to reporting.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| test-generator | `<prefix>-test-generator` | pilot-task-router, pilot-dataset, pilot-cron | Generates test cases from specs and stories, prioritizes by risk |
| executor | `<prefix>-executor` | pilot-task-parallel, pilot-share, pilot-metrics | Runs test suites, captures results, screenshots, and logs |
| reporter | `<prefix>-reporter` | pilot-webhook-bridge, pilot-alert, pilot-slack-bridge | Aggregates results, generates reports, files bugs, notifies team |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# test-generator:
clawhub install pilot-task-router pilot-dataset pilot-cron
# executor:
clawhub install pilot-task-parallel pilot-share pilot-metrics
# reporter:
clawhub install pilot-webhook-bridge pilot-alert pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/quality-assurance-pipeline.json << 'MANIFEST'
<USE ROLE TEMPLATE BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### test-generator
```json
{"setup":"quality-assurance-pipeline","setup_name":"Quality Assurance Pipeline","role":"test-generator","role_name":"Test Generator","hostname":"<prefix>-test-generator","description":"Generates test cases from specs, user stories, and code changes. Prioritizes by risk and coverage gaps.","skills":{"pilot-task-router":"Route test generation requests by type — unit, integration, e2e.","pilot-dataset":"Store specs, user stories, and historical test coverage data.","pilot-cron":"Schedule nightly regression suite generation and coverage gap analysis."},"peers":[{"role":"executor","hostname":"<prefix>-executor","description":"Receives test suites for execution"}],"data_flows":[{"direction":"send","peer":"<prefix>-executor","port":1002,"topic":"test-suite","description":"Test suites with cases, priorities, and environment configs"}],"handshakes_needed":["<prefix>-executor"]}
```

### executor
```json
{"setup":"quality-assurance-pipeline","setup_name":"Quality Assurance Pipeline","role":"executor","role_name":"Test Executor","hostname":"<prefix>-executor","description":"Runs automated test suites, captures results, screenshots, and logs. Handles parallel execution.","skills":{"pilot-task-parallel":"Run test cases in parallel across environments and browsers.","pilot-share":"Send test results, logs, and artifacts downstream to reporter.","pilot-metrics":"Track execution time, flake rate, and pass rate per suite."},"peers":[{"role":"test-generator","hostname":"<prefix>-test-generator","description":"Sends test suites for execution"},{"role":"reporter","hostname":"<prefix>-reporter","description":"Receives test results for aggregation"}],"data_flows":[{"direction":"receive","peer":"<prefix>-test-generator","port":1002,"topic":"test-suite","description":"Test suites with cases, priorities, and environment configs"},{"direction":"send","peer":"<prefix>-reporter","port":1002,"topic":"test-result","description":"Test results with pass/fail, logs, and screenshots"}],"handshakes_needed":["<prefix>-test-generator","<prefix>-reporter"]}
```

### reporter
```json
{"setup":"quality-assurance-pipeline","setup_name":"Quality Assurance Pipeline","role":"reporter","role_name":"QA Reporter","hostname":"<prefix>-reporter","description":"Aggregates test results, generates coverage reports, files bugs, notifies team.","skills":{"pilot-webhook-bridge":"Push bug reports to issue trackers and coverage data to dashboards.","pilot-alert":"Trigger alerts on test failures, coverage drops, and regressions.","pilot-slack-bridge":"Post QA summaries, failure details, and deploy readiness to Slack."},"peers":[{"role":"executor","hostname":"<prefix>-executor","description":"Sends test results for aggregation"}],"data_flows":[{"direction":"receive","peer":"<prefix>-executor","port":1002,"topic":"test-result","description":"Test results with pass/fail, logs, and screenshots"},{"direction":"send","peer":"external","port":443,"topic":"qa-report","description":"QA reports to dashboards, bug trackers, and Slack"}],"handshakes_needed":["<prefix>-executor"]}
```

## Data Flows

- `test-generator -> executor` : test-suite (port 1002)
- `executor -> reporter` : test-result (port 1002)
- `reporter -> external` : qa-report via webhook (port 443)

## Handshakes

```bash
# test-generator <-> executor:
pilotctl --json handshake <prefix>-executor "setup: quality-assurance-pipeline"
pilotctl --json handshake <prefix>-test-generator "setup: quality-assurance-pipeline"
# executor <-> reporter:
pilotctl --json handshake <prefix>-reporter "setup: quality-assurance-pipeline"
pilotctl --json handshake <prefix>-executor "setup: quality-assurance-pipeline"
```

## Workflow Example

```bash
# On executor -- subscribe to test suites:
pilotctl --json subscribe <prefix>-test-generator test-suite
# On reporter -- subscribe to test results:
pilotctl --json subscribe <prefix>-executor test-result
# On test-generator -- publish a test suite:
pilotctl --json publish <prefix>-executor test-suite '{"suite":"checkout-flow","cases":[{"id":"tc_001","name":"add_to_cart","priority":"high"}],"environment":"staging"}'
# On executor -- publish test results:
pilotctl --json publish <prefix>-reporter test-result '{"suite":"checkout-flow","total":1,"passed":1,"failed":0,"duration_ms":3200}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
