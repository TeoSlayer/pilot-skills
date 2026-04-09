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

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-policy — evaluate an agent action and route:
pilotctl publish <your-prefix>-auditor policy-violation '{"agent":"data-processor-3","action":"write_to_prod","rule":"require-approval","severity":"high"}'
pilotctl publish <your-prefix>-certifier cert-request '{"agent":"data-processor-1","scope":"prod-write","policy_checks_passed":true}'

# On <your-prefix>-auditor — log and forward to reporter:
pilotctl publish <your-prefix>-reporter audit-finding '{"finding_id":"AUD-0721","agent":"data-processor-3","violation":"unauthorized prod write","severity":"high"}'

# On <your-prefix>-certifier — issue cert and notify reporter:
pilotctl publish <your-prefix>-reporter cert-issued '{"agent":"data-processor-1","cert_id":"CERT-2024-0315","scope":"prod-write","expires":"2024-06-15"}'

# On <your-prefix>-reporter — generate summary:
pilotctl publish <your-prefix>-reporter slack-forward '{"channel":"#compliance","text":"Weekly report: 3 violations, 12 certs issued, 99.2% compliance rate"}'
```
