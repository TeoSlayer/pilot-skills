# CI/CD Pipeline Setup

A fully decentralized CI/CD pipeline where each stage runs on a separate agent. GitHub webhooks trigger builds, artifacts flow between stages over Pilot tunnels, and deployment receipts provide an audit trail.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### ci-builder (Build Agent)
Listens for GitHub push/PR webhooks, clones the repo, runs builds, and shares artifacts with the test agent.

**Skills:** pilot-task-router, pilot-share, pilot-github-bridge

### ci-tester (Test Agent)
Receives build artifacts, runs test suites, and logs results. Passes successful builds to the deployer.

**Skills:** pilot-task-router, pilot-share, pilot-audit-log

### ci-deployer (Deploy Agent)
Receives tested artifacts, deploys to production, sends deployment receipts, and triggers post-deploy webhooks.

**Skills:** pilot-task-router, pilot-share, pilot-webhook-bridge, pilot-receipt

## Data Flow

```
ci-builder  --> ci-tester  : Build artifacts and test instructions (port 1001)
ci-tester   --> ci-deployer : Tested artifacts with test report (port 1001)
ci-deployer --> ci-builder  : Deployment receipt back to origin (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On build server
clawhub install pilot-task-router pilot-share pilot-github-bridge
pilotctl set-hostname <your-prefix>-ci-builder

# On test server
clawhub install pilot-task-router pilot-share pilot-audit-log
pilotctl set-hostname <your-prefix>-ci-tester

# On deploy server
clawhub install pilot-task-router pilot-share pilot-webhook-bridge pilot-receipt
pilotctl set-hostname <your-prefix>-ci-deployer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On ci-builder:
pilotctl handshake <your-prefix>-ci-deployer "setup: ci-cd-pipeline"
# On ci-deployer:
pilotctl handshake <your-prefix>-ci-builder "setup: ci-cd-pipeline"
# On ci-builder:
pilotctl handshake <your-prefix>-ci-tester "setup: ci-cd-pipeline"
# On ci-tester:
pilotctl handshake <your-prefix>-ci-builder "setup: ci-cd-pipeline"
# On ci-deployer:
pilotctl handshake <your-prefix>-ci-tester "setup: ci-cd-pipeline"
# On ci-tester:
pilotctl handshake <your-prefix>-ci-deployer "setup: ci-cd-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-ci-builder — receive a GitHub webhook and send build artifact:
pilotctl send-file <your-prefix>-ci-tester ./build/app-v2.3.tar.gz
pilotctl publish <your-prefix>-ci-tester build-ready '{"commit":"a1b2c3d","branch":"main","artifact":"app-v2.3.tar.gz"}'

# On <your-prefix>-ci-tester — run tests and forward to deployer:
pilotctl send-file <your-prefix>-ci-deployer ./build/app-v2.3.tar.gz
pilotctl publish <your-prefix>-ci-deployer tests-passed '{"commit":"a1b2c3d","tests":142,"passed":142,"coverage":87}'

# On <your-prefix>-ci-deployer — deploy and send receipt:
pilotctl publish <your-prefix>-ci-builder deploy-receipt '{"commit":"a1b2c3d","env":"production","status":"success","url":"https://app.example.com"}'
```
