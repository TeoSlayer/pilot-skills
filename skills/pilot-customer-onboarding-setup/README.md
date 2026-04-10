# Customer Onboarding

Deploy a customer onboarding system with 3 agents that automate the new customer journey from welcome through product setup to long-term success tracking. A welcome bot greets customers and collects preferences, a setup guide walks them through configuration milestones, and a success tracker monitors adoption metrics to identify at-risk customers before they churn.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### welcome-bot (Welcome Bot)
Greets new customers, collects preferences, sends personalized welcome sequences. Captures initial profile data and routes customers to the appropriate onboarding path.

**Skills:** pilot-chat, pilot-announce, pilot-receipt

### setup-guide (Setup Guide)
Walks customers through product configuration, checks completion milestones, offers help. Tracks which setup steps are done and nudges on incomplete items.

**Skills:** pilot-task-chain, pilot-share, pilot-webhook-bridge

### success-tracker (Success Tracker)
Monitors adoption metrics, identifies at-risk customers, triggers intervention workflows. Generates health scores and escalates churning accounts to the team.

**Skills:** pilot-metrics, pilot-alert, pilot-slack-bridge

## Data Flow

```
welcome-bot     --> setup-guide     : Customer profiles with preferences and onboarding path (port 1002)
setup-guide     --> success-tracker : Onboarding progress with milestone completion data (port 1002)
success-tracker --> external        : Customer health reports to dashboards and Slack (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (welcome bot)
clawhub install pilot-chat pilot-announce pilot-receipt
pilotctl set-hostname <your-prefix>-welcome-bot

# On server 2 (setup guide)
clawhub install pilot-task-chain pilot-share pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-setup-guide

# On server 3 (success tracker)
clawhub install pilot-metrics pilot-alert pilot-slack-bridge
pilotctl set-hostname <your-prefix>-success-tracker
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# welcome-bot <-> setup-guide
# On welcome-bot:
pilotctl handshake <your-prefix>-setup-guide "setup: customer-onboarding"
# On setup-guide:
pilotctl handshake <your-prefix>-welcome-bot "setup: customer-onboarding"

# setup-guide <-> success-tracker
# On setup-guide:
pilotctl handshake <your-prefix>-success-tracker "setup: customer-onboarding"
# On success-tracker:
pilotctl handshake <your-prefix>-setup-guide "setup: customer-onboarding"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-setup-guide -- subscribe to customer profiles:
pilotctl subscribe <your-prefix>-welcome-bot customer-profile

# On <your-prefix>-welcome-bot -- publish a customer profile:
pilotctl publish <your-prefix>-setup-guide customer-profile '{"customer_id":"cust_8a3f","name":"Jane Smith","email":"jane@example.com","plan":"pro","preferences":{"industry":"saas","team_size":12,"goals":["integrations","reporting"]}}'

# On <your-prefix>-success-tracker -- subscribe to onboarding progress:
pilotctl subscribe <your-prefix>-setup-guide onboarding-progress

# On <your-prefix>-setup-guide -- publish onboarding progress:
pilotctl publish <your-prefix>-success-tracker onboarding-progress '{"customer_id":"cust_8a3f","milestones":{"account_created":true,"first_integration":true,"team_invited":false,"first_report":false},"completion":0.50,"days_since_signup":3}'

# On <your-prefix>-success-tracker -- publish external health report:
pilotctl publish <your-prefix>-success-tracker health-report '{"customer_id":"cust_8a3f","health_score":0.65,"risk_level":"medium","blocked_on":"team_invited","recommendation":"Send team invite reminder email","days_since_signup":5}'
```
