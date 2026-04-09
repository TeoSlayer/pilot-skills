# Legal Contract Review Setup

An automated contract review pipeline that extracts key terms from uploaded documents, assesses risk against compliance templates, and produces executive summaries with actionable recommendations. Three agents handle the full lifecycle from raw document to signed-off review.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### extractor (Clause Extractor)
Parses uploaded contracts (PDF/DOCX), extracts key terms, dates, obligations, parties, and monetary values into structured data. Archives the original document for audit purposes.

**Skills:** pilot-share, pilot-stream-data, pilot-archive

### assessor (Risk Assessor)
Evaluates extracted clauses against compliance templates, flags non-standard terms, identifies liability exposure and missing protections. Prioritizes findings by severity.

**Skills:** pilot-event-filter, pilot-alert, pilot-priority-queue

### summarizer (Summary Generator)
Produces executive summaries with risk scores, comparison tables against standard templates, and actionable recommendations. Delivers final reports via webhook.

**Skills:** pilot-announce, pilot-webhook-bridge, pilot-receipt

## Data Flow

```
extractor  --> assessor   : extracted clauses and metadata (port 1002)
assessor   --> summarizer  : risk assessment with flagged items (port 1002)
summarizer --> external    : executive summary report (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `legalco`).

### 1. Install skills on each server

```bash
# On server 1 (clause extractor)
clawhub install pilot-share pilot-stream-data pilot-archive
pilotctl set-hostname <your-prefix>-extractor

# On server 2 (risk assessor)
clawhub install pilot-event-filter pilot-alert pilot-priority-queue
pilotctl set-hostname <your-prefix>-assessor

# On server 3 (summary generator)
clawhub install pilot-announce pilot-webhook-bridge pilot-receipt
pilotctl set-hostname <your-prefix>-summarizer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# extractor <-> assessor (clause data flow)
# On extractor:
pilotctl handshake <your-prefix>-assessor "setup: legal-contract-review"
# On assessor:
pilotctl handshake <your-prefix>-extractor "setup: legal-contract-review"

# assessor <-> summarizer (risk assessment flow)
# On assessor:
pilotctl handshake <your-prefix>-summarizer "setup: legal-contract-review"
# On summarizer:
pilotctl handshake <your-prefix>-assessor "setup: legal-contract-review"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-extractor -- publish extracted clauses:
pilotctl publish <your-prefix>-assessor extracted-clauses '{"contract_id":"CTR-2026-0042","parties":["Acme Corp","Widget Inc"],"effective_date":"2026-05-01","term_months":24,"total_value":450000,"clauses":[{"type":"indemnification","text":"Party A shall indemnify...","section":"7.2"},{"type":"termination","text":"Either party may terminate with 30 days notice...","section":"12.1"}]}'

# On <your-prefix>-assessor -- publish risk assessment:
pilotctl publish <your-prefix>-summarizer risk-assessment '{"contract_id":"CTR-2026-0042","risk_score":7.2,"flags":[{"clause":"indemnification","severity":"high","issue":"Unlimited liability exposure for Party A"},{"clause":"termination","severity":"medium","issue":"30-day notice below standard 90-day threshold"}],"missing_protections":["limitation_of_liability","force_majeure"]}'

# On <your-prefix>-summarizer -- subscribe to risk assessments:
pilotctl subscribe risk-assessment
```
