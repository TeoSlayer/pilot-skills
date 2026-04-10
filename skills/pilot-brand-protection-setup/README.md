# Brand Protection

Deploy a brand protection system with 4 agents that monitor for unauthorized brand usage, classify threats, enforce takedowns, and visualize brand health. A scanner crawls marketplaces and social media for counterfeits and impersonation, a classifier categorizes violations by type and severity, an enforcer files DMCA notices and platform reports, and a dashboard tracks violation trends and enforcement success rates.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### scanner (Brand Scanner)
Crawls marketplaces, social media, and domain registrations for unauthorized brand usage, counterfeits, and impersonation attempts. Runs on configurable schedules.

**Skills:** pilot-stream-data, pilot-cron, pilot-archive

### classifier (Threat Classifier)
Classifies detected violations by type (counterfeit, impersonation, trademark), severity level, and originating platform. Scores each violation for enforcement priority.

**Skills:** pilot-event-filter, pilot-task-router, pilot-metrics

### enforcer (Takedown Enforcer)
Files DMCA notices, platform reports, and cease-and-desist requests against confirmed violations. Tracks enforcement status through resolution.

**Skills:** pilot-webhook-bridge, pilot-audit-log, pilot-receipt

### dashboard (Brand Dashboard)
Visualizes brand health metrics, violation trends over time, and enforcement success rates. Publishes periodic brand health reports.

**Skills:** pilot-metrics, pilot-slack-bridge, pilot-announce

## Data Flow

```
scanner    --> classifier : Brand violations detected across platforms (port 1002)
classifier --> enforcer   : Classified threats with type, severity, and priority (port 1002)
enforcer   --> dashboard  : Enforcement actions with status and outcomes (port 1002)
dashboard  --> external   : Brand health reports to stakeholders (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (brand scanner)
clawhub install pilot-stream-data pilot-cron pilot-archive
pilotctl set-hostname <your-prefix>-scanner

# On server 2 (threat classifier)
clawhub install pilot-event-filter pilot-task-router pilot-metrics
pilotctl set-hostname <your-prefix>-classifier

# On server 3 (takedown enforcer)
clawhub install pilot-webhook-bridge pilot-audit-log pilot-receipt
pilotctl set-hostname <your-prefix>-enforcer

# On server 4 (brand dashboard)
clawhub install pilot-metrics pilot-slack-bridge pilot-announce
pilotctl set-hostname <your-prefix>-dashboard
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# scanner <-> classifier
# On scanner:
pilotctl handshake <your-prefix>-classifier "setup: brand-protection"
# On classifier:
pilotctl handshake <your-prefix>-scanner "setup: brand-protection"

# classifier <-> enforcer
# On classifier:
pilotctl handshake <your-prefix>-enforcer "setup: brand-protection"
# On enforcer:
pilotctl handshake <your-prefix>-classifier "setup: brand-protection"

# enforcer <-> dashboard
# On enforcer:
pilotctl handshake <your-prefix>-dashboard "setup: brand-protection"
# On dashboard:
pilotctl handshake <your-prefix>-enforcer "setup: brand-protection"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-classifier -- subscribe to brand violations from scanner:
pilotctl subscribe <your-prefix>-scanner brand-violation

# On <your-prefix>-scanner -- publish a detected violation:
pilotctl publish <your-prefix>-classifier brand-violation '{"violation_id":"BV-20481","platform":"amazon","type":"counterfeit","brand":"Acme Corp","product":"Acme Pro Widget","listing_url":"https://amazon.com/dp/B0FAKE123","seller":"ShenzhenDirect","confidence":0.91,"evidence":["logo_match:98%","product_copy:87%"]}'

# On <your-prefix>-enforcer -- subscribe to classified threats:
pilotctl subscribe <your-prefix>-classifier classified-threat

# On <your-prefix>-classifier -- publish a classified threat:
pilotctl publish <your-prefix>-enforcer classified-threat '{"violation_id":"BV-20481","type":"counterfeit","severity":"high","platform":"amazon","priority_score":0.94,"recommended_action":"dmca_takedown","evidence_summary":"Logo match 98%, product copy 87%, seller history: 3 prior violations"}'

# On <your-prefix>-dashboard -- subscribe to enforcement actions:
pilotctl subscribe <your-prefix>-enforcer enforcement-action

# On <your-prefix>-enforcer -- publish an enforcement action:
pilotctl publish <your-prefix>-dashboard enforcement-action '{"violation_id":"BV-20481","action":"dmca_filed","platform":"amazon","case_ref":"DMCA-2026-04091","status":"pending","filed_at":"2026-04-09T14:30:00Z","expected_resolution":"72h"}'

# On <your-prefix>-dashboard -- publish brand health report:
pilotctl publish <your-prefix>-dashboard brand-report '{"period":"2026-W15","violations_detected":23,"takedowns_filed":18,"takedowns_resolved":14,"success_rate":0.78,"top_platform":"amazon","trend":"improving"}'
```
