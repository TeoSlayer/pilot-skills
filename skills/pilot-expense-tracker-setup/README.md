# Expense Tracker

Deploy an expense tracking pipeline with 3 agents that automate receipt collection, expense categorization, and report generation. Each agent handles one stage of the pipeline, turning raw receipts into categorized expense reports ready for manager approval.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### collector (Receipt Collector)
Accepts expense receipts via photo upload or email forward. Extracts amount, vendor, and category from each receipt and forwards structured expense data downstream.

**Skills:** pilot-stream-data, pilot-share, pilot-archive

### categorizer (Expense Categorizer)
Classifies expenses by category, flags policy violations, and calculates totals by period. Outputs enriched expense records with compliance status.

**Skills:** pilot-task-router, pilot-event-filter, pilot-metrics

### reporter (Expense Reporter)
Generates expense reports, submits for approval, and notifies managers via Slack. Handles report formatting and delivery to external systems.

**Skills:** pilot-webhook-bridge, pilot-announce, pilot-slack-bridge

## Data Flow

```
collector   --> categorizer : Raw expense data with amount, vendor, category (port 1002)
categorizer --> reporter    : Categorized expense with compliance flags (port 1002)
reporter    --> external    : Expense report submitted for approval (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (receipt collector)
clawhub install pilot-stream-data pilot-share pilot-archive
pilotctl set-hostname <your-prefix>-collector

# On server 2 (expense categorizer)
clawhub install pilot-task-router pilot-event-filter pilot-metrics
pilotctl set-hostname <your-prefix>-categorizer

# On server 3 (expense reporter)
clawhub install pilot-webhook-bridge pilot-announce pilot-slack-bridge
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# collector <-> categorizer
# On collector:
pilotctl handshake <your-prefix>-categorizer "setup: expense-tracker"
# On categorizer:
pilotctl handshake <your-prefix>-collector "setup: expense-tracker"

# categorizer <-> reporter
# On categorizer:
pilotctl handshake <your-prefix>-reporter "setup: expense-tracker"
# On reporter:
pilotctl handshake <your-prefix>-categorizer "setup: expense-tracker"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-categorizer -- subscribe to raw expenses from collector:
pilotctl subscribe <your-prefix>-collector raw-expense

# On <your-prefix>-reporter -- subscribe to categorized expenses:
pilotctl subscribe <your-prefix>-categorizer categorized-expense

# On <your-prefix>-collector -- publish a raw expense:
pilotctl publish <your-prefix>-categorizer raw-expense '{"vendor":"Delta Airlines","amount":487.50,"currency":"USD","date":"2025-03-12","receipt_type":"photo","category_hint":"travel","employee":"jane.smith"}'

# On <your-prefix>-categorizer -- publish a categorized expense to the reporter:
pilotctl publish <your-prefix>-reporter categorized-expense '{"vendor":"Delta Airlines","amount":487.50,"currency":"USD","category":"travel","subcategory":"airfare","policy_compliant":true,"period":"2025-Q1","employee":"jane.smith"}'

# The reporter generates and submits the expense report:
pilotctl publish <your-prefix>-reporter expense-report '{"channel":"#finance","text":"Expense report submitted: Q1-2025 Travel - Jane Smith ($2,340.00)","report_id":"EXP-2025-0042","status":"pending_approval","approver":"mike.johnson"}'
```
