---
name: pilot-compliance-governance-setup
description: >
  Deploy a compliance and governance system with 4 agents.

  Use this skill when:
  1. User wants to set up automated compliance enforcement
  2. User is configuring a policy engine, auditor, certifier, or reporter agent
  3. User asks about governance rules, audit trails, or compliance certification

  Do NOT use this skill when:
  - User wants a single audit log (use pilot-audit-log instead)
  - User wants to issue a single certificate (use pilot-certificate instead)
tags:
  - pilot-protocol
  - setup
  - compliance
  - governance
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

# Compliance & Governance Setup

Deploy 4 agents: policy engine, auditor, certifier, and reporter.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| policy-engine | `<prefix>-policy` | pilot-event-filter, pilot-sla, pilot-workflow, pilot-task-chain | Evaluates governance rules |
| auditor | `<prefix>-auditor` | pilot-audit-log, pilot-verify, pilot-event-log, pilot-cron | Tamper-evident audit trail |
| certifier | `<prefix>-certifier` | pilot-certificate, pilot-keychain, pilot-verify, pilot-receipt | Issues compliance certificates |
| reporter | `<prefix>-reporter` | pilot-metrics, pilot-webhook-bridge, pilot-slack-bridge, pilot-archive | Generates compliance reports |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# policy-engine:
clawhub install pilot-event-filter pilot-sla pilot-workflow pilot-task-chain
# auditor:
clawhub install pilot-audit-log pilot-verify pilot-event-log pilot-cron
# certifier:
clawhub install pilot-certificate pilot-keychain pilot-verify pilot-receipt
# reporter:
clawhub install pilot-metrics pilot-webhook-bridge pilot-slack-bridge pilot-archive
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/compliance-governance.json`.

**Step 4:** Handshake: policy↔auditor, policy↔certifier, auditor↔reporter, certifier↔reporter.

## Manifest Templates Per Role

### policy-engine
```json
{
  "setup": "compliance-governance", "role": "policy-engine", "role_name": "Policy Engine",
  "hostname": "<prefix>-policy",
  "skills": {
    "pilot-event-filter": "Evaluate agent actions against governance rules.",
    "pilot-sla": "Enforce SLA policies and response deadlines.",
    "pilot-workflow": "Define multi-step compliance workflows.",
    "pilot-task-chain": "Chain policy checks sequentially."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-auditor", "port": 1002, "topic": "policy-violation", "description": "Violations for logging" },
    { "direction": "send", "peer": "<prefix>-certifier", "port": 1002, "topic": "cert-request", "description": "Certification requests" }
  ],
  "handshakes_needed": ["<prefix>-auditor", "<prefix>-certifier"]
}
```

### auditor
```json
{
  "setup": "compliance-governance", "role": "auditor", "role_name": "Audit Trail",
  "hostname": "<prefix>-auditor",
  "skills": {
    "pilot-audit-log": "Maintain tamper-evident, append-only audit logs.",
    "pilot-verify": "Run periodic integrity checks on logs.",
    "pilot-event-log": "Searchable event log of all agent actions.",
    "pilot-cron": "Schedule periodic audit sweeps."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-policy", "port": 1002, "topic": "policy-violation", "description": "Violations" },
    { "direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "audit-finding", "description": "Audit data for reports" }
  ],
  "handshakes_needed": ["<prefix>-policy", "<prefix>-reporter"]
}
```

### certifier
```json
{
  "setup": "compliance-governance", "role": "certifier", "role_name": "Compliance Certifier",
  "hostname": "<prefix>-certifier",
  "skills": {
    "pilot-certificate": "Issue Ed25519-signed compliance certificates.",
    "pilot-keychain": "Manage signing keys with auto-expiry.",
    "pilot-verify": "Verify existing certificates.",
    "pilot-receipt": "Issue certification receipts."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-policy", "port": 1002, "topic": "cert-request", "description": "Certification requests" },
    { "direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "cert-issued", "description": "Certification records" }
  ],
  "handshakes_needed": ["<prefix>-policy", "<prefix>-reporter"]
}
```

### reporter
```json
{
  "setup": "compliance-governance", "role": "reporter", "role_name": "Compliance Reporter",
  "hostname": "<prefix>-reporter",
  "skills": {
    "pilot-metrics": "Aggregate compliance metrics (violation rates, cert counts).",
    "pilot-webhook-bridge": "Forward reports to external systems.",
    "pilot-slack-bridge": "Post compliance summaries to Slack.",
    "pilot-archive": "Archive reports for retention."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-auditor", "port": 1002, "topic": "audit-finding", "description": "Audit data" },
    { "direction": "receive", "peer": "<prefix>-certifier", "port": 1002, "topic": "cert-issued", "description": "Certification records" }
  ],
  "handshakes_needed": ["<prefix>-auditor", "<prefix>-certifier"]
}
```

## Data Flows

- `policy → auditor` : policy violations (port 1002)
- `policy → certifier` : certification requests (port 1002)
- `auditor → reporter` : audit data for reports (port 1002)
- `certifier → reporter` : certification records (port 1002)

## Workflow Example

```bash
# On policy-engine:
pilotctl --json publish <prefix>-auditor policy-violation '{"agent":"data-proc-3","action":"write_to_prod","severity":"high"}'
pilotctl --json publish <prefix>-certifier cert-request '{"agent":"data-proc-1","scope":"prod-write"}'
# On auditor:
pilotctl --json publish <prefix>-reporter audit-finding '{"finding_id":"AUD-721","violation":"unauthorized prod write"}'
# On certifier:
pilotctl --json publish <prefix>-reporter cert-issued '{"cert_id":"CERT-315","agent":"data-proc-1","scope":"prod-write"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
