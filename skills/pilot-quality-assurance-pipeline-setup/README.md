# Quality Assurance Pipeline

Deploy a quality assurance pipeline with 3 agents that automate test generation, execution, and reporting. A test generator creates test cases from specs and user stories, an executor runs automated suites and captures results, and a reporter aggregates outcomes into coverage reports and files bugs. The pipeline turns code changes into verified quality gates with minimal manual intervention.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### test-generator (Test Generator)
Generates test cases from specs, user stories, and code changes. Prioritizes by risk and coverage gaps to focus testing effort where it matters most.

**Skills:** pilot-task-router, pilot-dataset, pilot-cron

### executor (Test Executor)
Runs automated test suites, captures results, screenshots, and logs. Handles parallel execution across environments and retries flaky tests.

**Skills:** pilot-task-parallel, pilot-share, pilot-metrics

### reporter (QA Reporter)
Aggregates test results, generates coverage reports, files bugs, notifies team. Tracks quality trends over time and flags regressions.

**Skills:** pilot-webhook-bridge, pilot-alert, pilot-slack-bridge

## Data Flow

```
test-generator --> executor : Test suites with cases, priorities, and environment configs (port 1002)
executor       --> reporter : Test results with pass/fail, logs, and screenshots (port 1002)
reporter       --> external : QA reports to dashboards, bug trackers, and Slack (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (test generator)
clawhub install pilot-task-router pilot-dataset pilot-cron
pilotctl set-hostname <your-prefix>-test-generator

# On server 2 (test executor)
clawhub install pilot-task-parallel pilot-share pilot-metrics
pilotctl set-hostname <your-prefix>-executor

# On server 3 (QA reporter)
clawhub install pilot-webhook-bridge pilot-alert pilot-slack-bridge
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# test-generator <-> executor
# On test-generator:
pilotctl handshake <your-prefix>-executor "setup: quality-assurance-pipeline"
# On executor:
pilotctl handshake <your-prefix>-test-generator "setup: quality-assurance-pipeline"

# executor <-> reporter
# On executor:
pilotctl handshake <your-prefix>-reporter "setup: quality-assurance-pipeline"
# On reporter:
pilotctl handshake <your-prefix>-executor "setup: quality-assurance-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-executor -- subscribe to test suites:
pilotctl subscribe <your-prefix>-test-generator test-suite

# On <your-prefix>-test-generator -- publish a test suite:
pilotctl publish <your-prefix>-executor test-suite '{"suite":"checkout-flow","source":"user-story-42","cases":[{"id":"tc_001","name":"add_to_cart","priority":"high","type":"e2e"},{"id":"tc_002","name":"apply_coupon","priority":"medium","type":"integration"}],"environment":"staging","trigger":"pr-merge"}'

# On <your-prefix>-reporter -- subscribe to test results:
pilotctl subscribe <your-prefix>-executor test-result

# On <your-prefix>-executor -- publish test results:
pilotctl publish <your-prefix>-reporter test-result '{"suite":"checkout-flow","total":2,"passed":1,"failed":1,"failures":[{"id":"tc_002","name":"apply_coupon","error":"coupon validation timeout","duration_ms":5200}],"duration_ms":8400,"environment":"staging"}'

# On <your-prefix>-reporter -- publish external QA report:
pilotctl publish <your-prefix>-reporter qa-report '{"suite":"checkout-flow","status":"failed","pass_rate":0.50,"bugs_filed":1,"bug_ids":["BUG-1847"],"coverage":0.78,"recommendation":"Block deploy — checkout coupon flow regression"}'
```
