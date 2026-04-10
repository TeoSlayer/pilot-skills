---
name: pilot-penetration-testing-setup
description: >
  Deploy an automated penetration testing pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up a penetration testing or security assessment pipeline
  2. User is configuring an agent as part of a vulnerability scanning workflow
  3. User asks about recon, vulnerability scanning, exploit validation, or pentest reporting across agents

  Do NOT use this skill when:
  - User wants to run a single vulnerability scan (use pilot-task-parallel instead)
  - User wants to send a one-off security alert (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - security
  - pentest
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

# Penetration Testing Setup

Deploy 4 agents that perform recon, scan vulnerabilities, validate exploits, and generate reports.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| recon | `<prefix>-recon` | pilot-discover, pilot-stream-data, pilot-archive | DNS enumeration, port scanning, service fingerprinting |
| scanner | `<prefix>-scanner` | pilot-task-parallel, pilot-metrics, pilot-dataset | Vulnerability scans, CVE checks, misconfiguration detection |
| exploiter | `<prefix>-exploiter` | pilot-task-chain, pilot-audit-log, pilot-receipt | Safe proof-of-concept validation, exploitability confirmation |
| reporter | `<prefix>-reporter` | pilot-webhook-bridge, pilot-share, pilot-slack-bridge | Report generation with findings, risk ratings, remediation |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For recon:
clawhub install pilot-discover pilot-stream-data pilot-archive
# For scanner:
clawhub install pilot-task-parallel pilot-metrics pilot-dataset
# For exploiter:
clawhub install pilot-task-chain pilot-audit-log pilot-receipt
# For reporter:
clawhub install pilot-webhook-bridge pilot-share pilot-slack-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/penetration-testing.json << 'MANIFEST'
<INSERT ROLE MANIFEST FROM BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### recon
```json
{
  "setup": "penetration-testing", "setup_name": "Penetration Testing",
  "role": "recon", "role_name": "Reconnaissance Agent",
  "hostname": "<prefix>-recon",
  "description": "Performs passive and active reconnaissance — DNS enumeration, port scanning, service fingerprinting.",
  "skills": {
    "pilot-discover": "Enumerate DNS records, subdomains, and service endpoints.",
    "pilot-stream-data": "Stream port scan results and fingerprints in real time.",
    "pilot-archive": "Archive recon snapshots for baseline comparison."
  },
  "peers": [{"role": "scanner", "hostname": "<prefix>-scanner", "description": "Receives recon results for vulnerability scanning"}],
  "data_flows": [{"direction": "send", "peer": "<prefix>-scanner", "port": 1002, "topic": "recon-result", "description": "Recon results with target profile and services"}],
  "handshakes_needed": ["<prefix>-scanner"]
}
```

### scanner
```json
{
  "setup": "penetration-testing", "setup_name": "Penetration Testing",
  "role": "scanner", "role_name": "Vulnerability Scanner",
  "hostname": "<prefix>-scanner",
  "description": "Runs automated vulnerability scans, checks CVE databases, identifies misconfigurations.",
  "skills": {
    "pilot-task-parallel": "Run multiple scan tools in parallel across target services.",
    "pilot-metrics": "Track scan coverage, finding counts, and severity distribution.",
    "pilot-dataset": "Store CVE matches and vulnerability metadata."
  },
  "peers": [{"role": "recon", "hostname": "<prefix>-recon", "description": "Sends recon results"}, {"role": "exploiter", "hostname": "<prefix>-exploiter", "description": "Receives vulnerability findings"}],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-recon", "port": 1002, "topic": "recon-result", "description": "Recon results with target profile and services"},
    {"direction": "send", "peer": "<prefix>-exploiter", "port": 1002, "topic": "vulnerability", "description": "Vulnerability findings with CVE and severity"}
  ],
  "handshakes_needed": ["<prefix>-recon", "<prefix>-exploiter"]
}
```

### exploiter
```json
{
  "setup": "penetration-testing", "setup_name": "Penetration Testing",
  "role": "exploiter", "role_name": "Exploit Validator",
  "hostname": "<prefix>-exploiter",
  "description": "Validates discovered vulnerabilities with safe proof-of-concept tests, confirms exploitability.",
  "skills": {
    "pilot-task-chain": "Chain validation steps: verify, exploit, document evidence.",
    "pilot-audit-log": "Log all validation attempts with timestamps and results.",
    "pilot-receipt": "Confirm receipt of vulnerability findings from scanner."
  },
  "peers": [{"role": "scanner", "hostname": "<prefix>-scanner", "description": "Sends vulnerability findings"}, {"role": "reporter", "hostname": "<prefix>-reporter", "description": "Receives validated findings"}],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-scanner", "port": 1002, "topic": "vulnerability", "description": "Vulnerability findings with CVE and severity"},
    {"direction": "send", "peer": "<prefix>-reporter", "port": 1002, "topic": "validated-finding", "description": "Validated findings with proof-of-concept evidence"}
  ],
  "handshakes_needed": ["<prefix>-scanner", "<prefix>-reporter"]
}
```

### reporter
```json
{
  "setup": "penetration-testing", "setup_name": "Penetration Testing",
  "role": "reporter", "role_name": "Pentest Reporter",
  "hostname": "<prefix>-reporter",
  "description": "Generates pentest reports with findings, risk ratings, remediation steps, and executive summary.",
  "skills": {
    "pilot-webhook-bridge": "Deliver reports to client portals and ticketing systems.",
    "pilot-share": "Share report drafts with stakeholders for review.",
    "pilot-slack-bridge": "Notify security team of completed assessments."
  },
  "peers": [{"role": "exploiter", "hostname": "<prefix>-exploiter", "description": "Sends validated findings with evidence"}],
  "data_flows": [
    {"direction": "receive", "peer": "<prefix>-exploiter", "port": 1002, "topic": "validated-finding", "description": "Validated findings with proof-of-concept evidence"},
    {"direction": "send", "peer": "external", "port": 443, "topic": "pentest-report", "description": "Pentest report via webhook and Slack"}
  ],
  "handshakes_needed": ["<prefix>-exploiter"]
}
```

## Data Flows

- `recon -> scanner` : recon-result events (port 1002)
- `scanner -> exploiter` : vulnerability events (port 1002)
- `exploiter -> reporter` : validated-finding events (port 1002)
- `reporter -> external` : pentest-report via webhook (port 443)

## Handshakes

```bash
# recon <-> scanner:
pilotctl --json handshake <prefix>-scanner "setup: penetration-testing"
pilotctl --json handshake <prefix>-recon "setup: penetration-testing"
# scanner <-> exploiter:
pilotctl --json handshake <prefix>-exploiter "setup: penetration-testing"
pilotctl --json handshake <prefix>-scanner "setup: penetration-testing"
# exploiter <-> reporter:
pilotctl --json handshake <prefix>-reporter "setup: penetration-testing"
pilotctl --json handshake <prefix>-exploiter "setup: penetration-testing"
```

## Workflow Example

```bash
# On scanner — subscribe to recon results:
pilotctl --json subscribe <prefix>-recon recon-result
# On exploiter — subscribe to vulnerabilities:
pilotctl --json subscribe <prefix>-scanner vulnerability
# On reporter — subscribe to validated findings:
pilotctl --json subscribe <prefix>-exploiter validated-finding
# On recon — publish a recon result:
pilotctl --json publish <prefix>-scanner recon-result '{"target":"app.example.com","open_ports":[22,80,443,8080]}'
# On exploiter — publish a validated finding:
pilotctl --json publish <prefix>-reporter validated-finding '{"cve":"CVE-2023-46589","validated":true,"impact":"RCE"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
