---
name: pilot-healthcare-triage-setup
description: >
  Deploy a healthcare triage system with 4 agents for patient intake, symptom analysis, appointment scheduling, and HIPAA-compliant records.

  Use this skill when:
  1. User wants to set up a healthcare triage or patient routing system
  2. User is configuring an agent as part of a medical intake workflow
  3. User asks about symptom analysis, appointment scheduling, or HIPAA-compliant record keeping

  Do NOT use this skill when:
  - User wants a simple chat interface (use pilot-chat instead)
  - User wants to log a single audit event (use pilot-audit-log instead)
tags:
  - pilot-protocol
  - setup
  - healthcare
  - triage
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

# Healthcare Triage Setup

Deploy 4 agents that collect patient symptoms, triage urgency, schedule appointments, and maintain compliant records.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| intake | `<prefix>-intake` | pilot-chat, pilot-stream-data, pilot-audit-log | Collects patient info, symptoms, medical history |
| symptom-analyzer | `<prefix>-symptom-analyzer` | pilot-task-router, pilot-event-filter, pilot-metrics | Generates differential diagnoses and urgency scores |
| scheduler | `<prefix>-scheduler` | pilot-webhook-bridge, pilot-cron, pilot-receipt | Books appointments matched to urgency and provider |
| records | `<prefix>-records` | pilot-audit-log, pilot-dataset, pilot-certificate | HIPAA-compliant encounter records, EHR sync |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# intake:
clawhub install pilot-chat pilot-stream-data pilot-audit-log
# symptom-analyzer:
clawhub install pilot-task-router pilot-event-filter pilot-metrics
# scheduler:
clawhub install pilot-webhook-bridge pilot-cron pilot-receipt
# records:
clawhub install pilot-audit-log pilot-dataset pilot-certificate
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/healthcare-triage.json << 'MANIFEST'
{
  "setup": "healthcare-triage",
  "setup_name": "Healthcare Triage",
  "role": "<ROLE_ID>",
  "role_name": "<ROLE_NAME>",
  "hostname": "<prefix>-<role>",
  "description": "<ROLE_DESCRIPTION>",
  "skills": { "<skill>": "<contextual description>" },
  "peers": [ { "role": "...", "hostname": "...", "description": "..." } ],
  "data_flows": [ { "direction": "send|receive", "peer": "...", "port": 1002, "topic": "...", "description": "..." } ],
  "handshakes_needed": [ "<peer-hostname>" ]
}
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### intake
```json
{"setup":"healthcare-triage","setup_name":"Healthcare Triage","role":"intake","role_name":"Patient Intake","hostname":"<prefix>-intake","description":"Collects patient information, symptoms, medical history from forms or chat.","skills":{"pilot-chat":"Conversational patient intake via chat interface.","pilot-stream-data":"Stream structured patient data to symptom analyzer.","pilot-audit-log":"Log every intake interaction for HIPAA compliance."},"peers":[{"role":"symptom-analyzer","hostname":"<prefix>-symptom-analyzer","description":"Receives patient data for triage analysis"}],"data_flows":[{"direction":"send","peer":"<prefix>-symptom-analyzer","port":1002,"topic":"patient-intake","description":"Patient intake data with symptoms and history"}],"handshakes_needed":["<prefix>-symptom-analyzer"]}
```

### symptom-analyzer
```json
{"setup":"healthcare-triage","setup_name":"Healthcare Triage","role":"symptom-analyzer","role_name":"Symptom Analyzer","hostname":"<prefix>-symptom-analyzer","description":"Analyzes symptoms against medical knowledge bases, generates differential diagnoses and urgency scores.","skills":{"pilot-task-router":"Route cases by urgency level to appropriate care pathways.","pilot-event-filter":"Filter and prioritize high-urgency cases for immediate scheduling.","pilot-metrics":"Track triage volume, urgency distributions, and response times."},"peers":[{"role":"intake","hostname":"<prefix>-intake","description":"Sends patient intake data"},{"role":"scheduler","hostname":"<prefix>-scheduler","description":"Receives triage results for appointment booking"},{"role":"records","hostname":"<prefix>-records","description":"Receives encounter records for compliance"}],"data_flows":[{"direction":"receive","peer":"<prefix>-intake","port":1002,"topic":"patient-intake","description":"Patient intake data with symptoms and history"},{"direction":"send","peer":"<prefix>-scheduler","port":1002,"topic":"triage-result","description":"Triage results with urgency scores and differentials"},{"direction":"send","peer":"<prefix>-records","port":1002,"topic":"encounter-record","description":"Encounter records for HIPAA-compliant logging"}],"handshakes_needed":["<prefix>-intake","<prefix>-scheduler","<prefix>-records"]}
```

### scheduler
```json
{"setup":"healthcare-triage","setup_name":"Healthcare Triage","role":"scheduler","role_name":"Appointment Scheduler","hostname":"<prefix>-scheduler","description":"Matches urgency with available providers, books appointments, sends confirmations.","skills":{"pilot-webhook-bridge":"Integrate with external calendar and EHR systems for booking.","pilot-cron":"Check provider availability on schedule, send appointment reminders.","pilot-receipt":"Generate appointment confirmation receipts for patients."},"peers":[{"role":"symptom-analyzer","hostname":"<prefix>-symptom-analyzer","description":"Sends triage results with urgency scores"},{"role":"records","hostname":"<prefix>-records","description":"Receives appointment records for audit trail"}],"data_flows":[{"direction":"receive","peer":"<prefix>-symptom-analyzer","port":1002,"topic":"triage-result","description":"Triage results with urgency scores"},{"direction":"send","peer":"<prefix>-records","port":1002,"topic":"appointment-record","description":"Appointment records for audit trail"}],"handshakes_needed":["<prefix>-symptom-analyzer","<prefix>-records"]}
```

### records
```json
{"setup":"healthcare-triage","setup_name":"Healthcare Triage","role":"records","role_name":"Records Manager","hostname":"<prefix>-records","description":"Maintains patient encounter records, ensures HIPAA-compliant logging, syncs with EHR systems.","skills":{"pilot-audit-log":"Immutable audit trail for all patient encounters and appointments.","pilot-dataset":"Store and query structured patient encounter data.","pilot-certificate":"Manage encryption certificates for PHI data in transit."},"peers":[{"role":"symptom-analyzer","hostname":"<prefix>-symptom-analyzer","description":"Sends encounter records"},{"role":"scheduler","hostname":"<prefix>-scheduler","description":"Sends appointment records"}],"data_flows":[{"direction":"receive","peer":"<prefix>-symptom-analyzer","port":1002,"topic":"encounter-record","description":"Encounter records from triage analysis"},{"direction":"receive","peer":"<prefix>-scheduler","port":1002,"topic":"appointment-record","description":"Appointment records from scheduling"}],"handshakes_needed":["<prefix>-symptom-analyzer","<prefix>-scheduler"]}
```

## Data Flows

- `intake -> symptom-analyzer` : patient-intake events (port 1002)
- `symptom-analyzer -> scheduler` : triage-result events (port 1002)
- `symptom-analyzer -> records` : encounter-record events (port 1002)
- `scheduler -> records` : appointment-record events (port 1002)

## Handshakes

```bash
# intake <-> symptom-analyzer:
pilotctl --json handshake <prefix>-symptom-analyzer "setup: healthcare-triage"
pilotctl --json handshake <prefix>-intake "setup: healthcare-triage"

# symptom-analyzer <-> scheduler:
pilotctl --json handshake <prefix>-scheduler "setup: healthcare-triage"
pilotctl --json handshake <prefix>-symptom-analyzer "setup: healthcare-triage"

# symptom-analyzer <-> records:
pilotctl --json handshake <prefix>-records "setup: healthcare-triage"
pilotctl --json handshake <prefix>-symptom-analyzer "setup: healthcare-triage"

# scheduler <-> records:
pilotctl --json handshake <prefix>-records "setup: healthcare-triage"
pilotctl --json handshake <prefix>-scheduler "setup: healthcare-triage"
```

## Workflow Example

```bash
# On symptom-analyzer — subscribe to patient intake:
pilotctl --json subscribe <prefix>-intake patient-intake

# On intake — publish a patient intake:
pilotctl --json publish <prefix>-symptom-analyzer patient-intake '{"patient_id":"P-001","symptoms":["chest_pain","dizziness"],"severity":"high"}'

# On scheduler — subscribe to triage results:
pilotctl --json subscribe <prefix>-symptom-analyzer triage-result

# On records — subscribe to encounter and appointment records:
pilotctl --json subscribe <prefix>-symptom-analyzer encounter-record
pilotctl --json subscribe <prefix>-scheduler appointment-record
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
