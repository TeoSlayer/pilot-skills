# Customer Support Triage Setup

Deploy a support ticket triage system where incoming tickets are classified by urgency and category, routine issues are auto-resolved from a knowledge base, and complex cases are enriched with context and escalated to human agents. The three agents work together to reduce response times and ensure no ticket falls through the cracks.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### triage-bot (Triage Bot)
Receives incoming support tickets, classifies them by urgency (low, medium, high, critical) and category (billing, technical, account, general), and routes to the appropriate handler.

**Skills:** pilot-event-filter, pilot-priority-queue, pilot-task-router

### resolver (Auto-Resolver)
Handles routine queries using knowledge base lookups -- order status, FAQs, password resets, and common troubleshooting steps. Sends resolution receipts back for audit.

**Skills:** pilot-task-router, pilot-receipt, pilot-audit-log

### escalator (Escalation Agent)
Takes complex issues that the auto-resolver cannot handle, enriches them with customer history and account context, and forwards to human support via webhook or Slack.

**Skills:** pilot-webhook-bridge, pilot-slack-bridge, pilot-alert

## Data Flow

```
triage-bot --> resolver  : Routine tickets for automated resolution (port 1002)
triage-bot --> escalator : Complex tickets requiring human attention (port 1002)
escalator  --> external  : Escalated tickets to helpdesk and Slack (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (triage bot)
clawhub install pilot-event-filter pilot-priority-queue pilot-task-router
pilotctl set-hostname <your-prefix>-triage-bot

# On server 2 (auto-resolver)
clawhub install pilot-task-router pilot-receipt pilot-audit-log
pilotctl set-hostname <your-prefix>-resolver

# On server 3 (escalation agent)
clawhub install pilot-webhook-bridge pilot-slack-bridge pilot-alert
pilotctl set-hostname <your-prefix>-escalator
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# triage-bot <-> resolver
# On triage-bot:
pilotctl handshake <your-prefix>-resolver "setup: customer-support-triage"
# On resolver:
pilotctl handshake <your-prefix>-triage-bot "setup: customer-support-triage"

# triage-bot <-> escalator
# On triage-bot:
pilotctl handshake <your-prefix>-escalator "setup: customer-support-triage"
# On escalator:
pilotctl handshake <your-prefix>-triage-bot "setup: customer-support-triage"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-resolver -- subscribe to routine tickets:
pilotctl subscribe <your-prefix>-triage-bot ticket-routine

# On <your-prefix>-escalator -- subscribe to complex tickets:
pilotctl subscribe <your-prefix>-triage-bot ticket-complex

# On <your-prefix>-triage-bot -- route a routine ticket (password reset):
pilotctl publish <your-prefix>-resolver ticket-routine '{"ticket_id":"TK-4821","category":"account","urgency":"low","subject":"Password reset request","customer":"jane@example.com"}'

# On <your-prefix>-triage-bot -- route a complex ticket (data loss):
pilotctl publish <your-prefix>-escalator ticket-complex '{"ticket_id":"TK-4822","category":"technical","urgency":"critical","subject":"Production database showing missing records","customer":"ops@bigcorp.com","account_tier":"enterprise"}'

# The escalator enriches context and forwards to the helpdesk:
pilotctl publish <your-prefix>-escalator escalation '{"channel":"#support-escalations","text":"CRITICAL: TK-4822 - Production data loss for enterprise account bigcorp","helpdesk_url":"https://help.acme.com/tickets/TK-4822"}'
```
