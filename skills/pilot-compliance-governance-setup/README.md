# Compliance & Governance Setup

Automated compliance for regulated environments. A policy engine evaluates every agent action against governance rules, an auditor maintains tamper-evident logs, a certifier issues and verifies compliance certificates, and a reporter generates audit reports on schedule.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### policy (Policy Engine)
Evaluates agent actions against governance rules and SLA policies. Blocks non-compliant actions and routes violations to the auditor.

**Skills:** pilot-event-filter, pilot-sla, pilot-workflow, pilot-task-chain

### auditor (Audit Trail)
Maintains tamper-evident, append-only logs of all agent actions. Runs periodic integrity checks and flags anomalies.

**Skills:** pilot-audit-log, pilot-verify, pilot-event-log, pilot-cron

### certifier (Compliance Certifier)
Issues compliance certificates to agents that pass policy checks. Manages a keychain for certificate signing and issues receipts for every certification.

**Skills:** pilot-certificate, pilot-keychain, pilot-verify, pilot-receipt

### reporter (Compliance Reporter)
Generates periodic compliance reports from audit logs and certification data. Archives reports and sends summaries to stakeholders via Slack and webhooks.

**Skills:** pilot-metrics, pilot-webhook-bridge, pilot-slack-bridge, pilot-archive

## Data Flow

```
policy    --> auditor   : Policy violations and action logs (port 1002)
policy    --> certifier : Compliance certification requests for passing agents (port 1002)
auditor   --> reporter  : Audit data for reports (port 1002)
certifier --> reporter  : Certification records for reports (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On policy engine node
clawhub install pilot-event-filter pilot-sla pilot-workflow pilot-task-chain
pilotctl set-hostname <your-prefix>-policy

# On auditor node
clawhub install pilot-audit-log pilot-verify pilot-event-log pilot-cron
pilotctl set-hostname <your-prefix>-auditor

# On certifier node
clawhub install pilot-certificate pilot-keychain pilot-verify pilot-receipt
pilotctl set-hostname <your-prefix>-certifier

# On reporter node
clawhub install pilot-metrics pilot-webhook-bridge pilot-slack-bridge pilot-archive
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# policy <-> auditor
# On policy:
pilotctl handshake <your-prefix>-auditor "compliance"
# On auditor:
pilotctl handshake <your-prefix>-policy "compliance"

# policy <-> certifier
# On policy:
pilotctl handshake <your-prefix>-certifier "compliance"
# On certifier:
pilotctl handshake <your-prefix>-policy "compliance"

# auditor <-> reporter
# On auditor:
pilotctl handshake <your-prefix>-reporter "compliance"
# On reporter:
pilotctl handshake <your-prefix>-auditor "compliance"

# certifier <-> reporter
# On certifier:
pilotctl handshake <your-prefix>-reporter "compliance"
# On reporter:
pilotctl handshake <your-prefix>-certifier "compliance"
```

### 3. Verify

```bash
pilotctl trust
```
