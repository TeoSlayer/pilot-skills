# Healthcare Triage

Deploy a healthcare triage system with 4 agents that collects patient symptoms, performs differential diagnosis with urgency scoring, schedules appointments with matched providers, and maintains HIPAA-compliant encounter records. The system ensures every patient interaction is logged, auditable, and routed to the right care level.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### intake (Patient Intake)
Collects patient information, symptoms, and medical history from forms or chat interfaces. Structures data and forwards to symptom analysis.

**Skills:** pilot-chat, pilot-stream-data, pilot-audit-log

### symptom-analyzer (Symptom Analyzer)
Analyzes reported symptoms against medical knowledge bases, generates differential diagnoses and urgency scores. Routes results to scheduling and records.

**Skills:** pilot-task-router, pilot-event-filter, pilot-metrics

### scheduler (Appointment Scheduler)
Matches urgency levels with available providers, books appointments, and sends confirmations to patients. Integrates with external calendar systems.

**Skills:** pilot-webhook-bridge, pilot-cron, pilot-receipt

### records (Records Manager)
Maintains patient encounter records, ensures HIPAA-compliant logging, and syncs with EHR systems. Provides audit trail for all patient interactions.

**Skills:** pilot-audit-log, pilot-dataset, pilot-certificate

## Data Flow

```
intake           --> symptom-analyzer : Patient intake data with symptoms (port 1002)
symptom-analyzer --> scheduler        : Triage results with urgency scores (port 1002)
symptom-analyzer --> records          : Encounter records for compliance logging (port 1002)
scheduler        --> records          : Appointment records for audit trail (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (patient intake)
clawhub install pilot-chat pilot-stream-data pilot-audit-log
pilotctl set-hostname <your-prefix>-intake

# On server 2 (symptom analysis)
clawhub install pilot-task-router pilot-event-filter pilot-metrics
pilotctl set-hostname <your-prefix>-symptom-analyzer

# On server 3 (appointment scheduling)
clawhub install pilot-webhook-bridge pilot-cron pilot-receipt
pilotctl set-hostname <your-prefix>-scheduler

# On server 4 (records management)
clawhub install pilot-audit-log pilot-dataset pilot-certificate
pilotctl set-hostname <your-prefix>-records
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On intake:
pilotctl handshake <your-prefix>-symptom-analyzer "setup: healthcare-triage"
# On symptom-analyzer:
pilotctl handshake <your-prefix>-intake "setup: healthcare-triage"

# On symptom-analyzer:
pilotctl handshake <your-prefix>-scheduler "setup: healthcare-triage"
# On scheduler:
pilotctl handshake <your-prefix>-symptom-analyzer "setup: healthcare-triage"

# On symptom-analyzer:
pilotctl handshake <your-prefix>-records "setup: healthcare-triage"
# On records:
pilotctl handshake <your-prefix>-symptom-analyzer "setup: healthcare-triage"

# On scheduler:
pilotctl handshake <your-prefix>-records "setup: healthcare-triage"
# On records:
pilotctl handshake <your-prefix>-scheduler "setup: healthcare-triage"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-symptom-analyzer — subscribe to patient intake:
pilotctl subscribe <your-prefix>-intake patient-intake

# On <your-prefix>-intake — publish a patient intake:
pilotctl publish <your-prefix>-symptom-analyzer patient-intake '{"patient_id":"P-20240315-001","age":45,"symptoms":["chest_pain","shortness_of_breath","dizziness"],"duration":"2 hours","severity":"high","history":["hypertension","diabetes_type2"]}'

# On <your-prefix>-scheduler — subscribe to triage results:
pilotctl subscribe <your-prefix>-symptom-analyzer triage-result

# On <your-prefix>-symptom-analyzer — publish a triage result:
pilotctl publish <your-prefix>-scheduler triage-result '{"patient_id":"P-20240315-001","urgency":"emergent","score":9.2,"differentials":["acute_coronary_syndrome","pulmonary_embolism","panic_attack"],"recommended":"cardiology_stat"}'

# On <your-prefix>-records — subscribe to encounter records:
pilotctl subscribe <your-prefix>-symptom-analyzer encounter-record
pilotctl subscribe <your-prefix>-scheduler appointment-record

# On <your-prefix>-scheduler — publish an appointment record:
pilotctl publish <your-prefix>-records appointment-record '{"patient_id":"P-20240315-001","provider":"Dr. Chen","specialty":"cardiology","time":"2024-03-15T14:30:00Z","urgency":"emergent","location":"ER-Bay-3"}'
```
