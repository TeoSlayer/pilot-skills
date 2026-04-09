# Dev Team Assistants Setup

A team of four agents that automate the PR workflow. A coordinator watches GitHub for new PRs and fans out tasks to specialized agents: one reviews code, one runs tests, one generates documentation. Results are collected and posted as a unified PR summary.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### reviewer (Code Reviewer)
Analyzes PR diffs for code quality, security issues, and style violations. Posts review comments directly on the PR.

**Skills:** pilot-github-bridge, pilot-review, pilot-chat

### doc-writer (Documentation Writer)
Reads PR changes and generates or updates relevant documentation. Shares doc drafts with the coordinator.

**Skills:** pilot-github-bridge, pilot-share, pilot-task-router

### test-runner (Test Runner)
Checks out the PR branch, runs the full test suite, and reports results with coverage metrics.

**Skills:** pilot-github-bridge, pilot-task-router, pilot-audit-log

### coordinator (PR Coordinator)
Watches GitHub for new PRs, fans out review/test/doc tasks, collects results, and posts a unified summary comment on the PR.

**Skills:** pilot-github-bridge, pilot-task-chain, pilot-slack-bridge, pilot-broadcast

## Data Flow

```
coordinator --> reviewer    : PR details for code review (port 1002)
coordinator --> test-runner : PR details for test execution (port 1002)
coordinator --> doc-writer  : PR details for doc generation (port 1002)
reviewer    --> coordinator : Review findings and comments (port 1002)
test-runner --> coordinator : Test results and coverage (port 1002)
doc-writer  --> coordinator : Generated documentation (port 1001)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On review server
clawhub install pilot-github-bridge pilot-review pilot-chat
pilotctl set-hostname <your-prefix>-reviewer

# On docs server
clawhub install pilot-github-bridge pilot-share pilot-task-router
pilotctl set-hostname <your-prefix>-doc-writer

# On test server
clawhub install pilot-github-bridge pilot-task-router pilot-audit-log
pilotctl set-hostname <your-prefix>-test-runner

# On coordinator server
clawhub install pilot-github-bridge pilot-task-chain pilot-slack-bridge pilot-broadcast
pilotctl set-hostname <your-prefix>-coordinator
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On coordinator:
pilotctl handshake <your-prefix>-doc-writer "setup: dev-team-assistants"
# On doc-writer:
pilotctl handshake <your-prefix>-coordinator "setup: dev-team-assistants"
# On coordinator:
pilotctl handshake <your-prefix>-reviewer "setup: dev-team-assistants"
# On reviewer:
pilotctl handshake <your-prefix>-coordinator "setup: dev-team-assistants"
# On coordinator:
pilotctl handshake <your-prefix>-test-runner "setup: dev-team-assistants"
# On test-runner:
pilotctl handshake <your-prefix>-coordinator "setup: dev-team-assistants"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-coordinator — fan out a new PR to all assistants:
pilotctl task submit <your-prefix>-reviewer --task '{"pr":1234,"repo":"acme/api","action":"review","diff_url":"https://github.com/acme/api/pull/1234.diff"}'
pilotctl task submit <your-prefix>-test-runner --task '{"pr":1234,"repo":"acme/api","action":"test","branch":"feature/auth"}'
pilotctl task submit <your-prefix>-doc-writer --task '{"pr":1234,"repo":"acme/api","action":"docs","changed_files":["auth.go","middleware.go"]}'

# On <your-prefix>-reviewer — return findings:
pilotctl publish <your-prefix>-coordinator review-result '{"pr":1234,"issues":2,"approval":"changes_requested","comments":["missing error check on line 45"]}'

# On <your-prefix>-test-runner — return test results:
pilotctl publish <your-prefix>-coordinator test-result '{"pr":1234,"passed":89,"failed":0,"coverage":82}'

# On <your-prefix>-doc-writer — return generated docs:
pilotctl send-file <your-prefix>-coordinator ./docs/auth-middleware.md
pilotctl publish <your-prefix>-coordinator docs-result '{"pr":1234,"files_generated":["auth-middleware.md"]}'
```
