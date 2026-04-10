# Code Review Pipeline

Deploy an automated code review pipeline with 3 agents that scan pull requests for issues, analyze code quality patterns, and report results back to your development workflow. Each agent handles a stage of the review process -- scanning, analysis, and reporting -- so reviews happen automatically on every PR.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### scanner (Code Scanner)
Runs static analysis, linting, and security scans on PRs. Collects scan results into structured events for downstream review.

**Skills:** pilot-github-bridge, pilot-task-router, pilot-metrics

### reviewer (Code Reviewer)
Analyzes scan results, checks code patterns, suggests improvements. Produces a review verdict with actionable feedback.

**Skills:** pilot-event-filter, pilot-alert, pilot-audit-log

### reporter (Review Reporter)
Formats review results, posts PR comments, tracks metrics. Dispatches notifications to Slack and external systems.

**Skills:** pilot-webhook-bridge, pilot-slack-bridge, pilot-receipt

## Data Flow

```
scanner  --> reviewer  : Scan results with findings and severity (port 1002)
reviewer --> reporter  : Review verdict with suggestions and approval status (port 1002)
reporter --> external  : Review notification posted to PR and Slack (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (code scanner)
clawhub install pilot-github-bridge pilot-task-router pilot-metrics
pilotctl set-hostname <your-prefix>-scanner

# On server 2 (code reviewer)
clawhub install pilot-event-filter pilot-alert pilot-audit-log
pilotctl set-hostname <your-prefix>-reviewer

# On server 3 (review reporter)
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-receipt
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On reviewer:
pilotctl handshake <your-prefix>-scanner "setup: code-review-pipeline"
# On scanner:
pilotctl handshake <your-prefix>-reviewer "setup: code-review-pipeline"
# On reporter:
pilotctl handshake <your-prefix>-reviewer "setup: code-review-pipeline"
# On reviewer:
pilotctl handshake <your-prefix>-reporter "setup: code-review-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-reviewer — subscribe to scan results from scanner:
pilotctl subscribe <your-prefix>-scanner scan-result

# On <your-prefix>-reporter — subscribe to review verdicts from reviewer:
pilotctl subscribe <your-prefix>-reviewer review-verdict

# On <your-prefix>-scanner — publish a scan result:
pilotctl publish <your-prefix>-reviewer scan-result '{"pr":142,"repo":"acme/api","findings":[{"file":"auth.go","line":58,"severity":"high","rule":"sql-injection"}],"summary":"1 high, 0 medium, 0 low"}'

# On <your-prefix>-reviewer — publish a review verdict:
pilotctl publish <your-prefix>-reporter review-verdict '{"pr":142,"repo":"acme/api","status":"changes_requested","comments":1,"suggestion":"Use parameterized queries in auth.go:58"}'

# The reporter receives the verdict and posts to Slack:
pilotctl publish <your-prefix>-reporter review-notification '{"channel":"#code-review","text":"PR #142 acme/api: changes requested — 1 finding"}'
```
