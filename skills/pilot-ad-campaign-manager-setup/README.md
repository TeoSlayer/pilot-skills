# Ad Campaign Manager

Deploy an ad campaign management system with 4 agents that automate campaign strategy, creative production, real-time bidding, and performance analytics. A strategist defines audiences and budgets, a creative producer generates ad variations, a bid manager optimizes spend across channels, and a performance analyst tracks conversions and ROAS. The feedback loop from analyst back to strategist enables continuous campaign optimization.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### strategist (Campaign Strategist)
Defines target audiences, budgets, channel mix, and KPIs for ad campaigns. Creates campaign briefs that drive the entire pipeline from creative to bidding.

**Skills:** pilot-task-router, pilot-dataset, pilot-cron

### creative (Creative Producer)
Generates ad copy, headlines, and creative briefs. A/B tests variations across formats and channels to maximize engagement rates.

**Skills:** pilot-share, pilot-task-parallel, pilot-receipt

### bidder (Bid Manager)
Manages real-time bidding, adjusts bids based on performance, optimizes spend across channels. Balances budget allocation against conversion targets.

**Skills:** pilot-metrics, pilot-stream-data, pilot-escrow

### analyst (Performance Analyst)
Tracks conversions, ROAS, CTR. Generates reports and optimization recommendations. Feeds insights back to the strategist for campaign refinement.

**Skills:** pilot-event-filter, pilot-slack-bridge, pilot-webhook-bridge

## Data Flow

```
strategist --> creative  : Campaign briefs with audiences, budgets, and KPIs (port 1002)
creative   --> bidder    : Creative assets with A/B variants and targeting params (port 1002)
bidder     --> analyst   : Bid results with spend, impressions, and click data (port 1002)
analyst    --> strategist: Performance insights and optimization recommendations (port 1002)
analyst    --> external  : Campaign reports to dashboards and stakeholders (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (campaign strategist)
clawhub install pilot-task-router pilot-dataset pilot-cron
pilotctl set-hostname <your-prefix>-strategist

# On server 2 (creative producer)
clawhub install pilot-share pilot-task-parallel pilot-receipt
pilotctl set-hostname <your-prefix>-creative

# On server 3 (bid manager)
clawhub install pilot-metrics pilot-stream-data pilot-escrow
pilotctl set-hostname <your-prefix>-bidder

# On server 4 (performance analyst)
clawhub install pilot-event-filter pilot-slack-bridge pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-analyst
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# strategist <-> creative
# On strategist:
pilotctl handshake <your-prefix>-creative "setup: ad-campaign-manager"
# On creative:
pilotctl handshake <your-prefix>-strategist "setup: ad-campaign-manager"

# creative <-> bidder
# On creative:
pilotctl handshake <your-prefix>-bidder "setup: ad-campaign-manager"
# On bidder:
pilotctl handshake <your-prefix>-creative "setup: ad-campaign-manager"

# bidder <-> analyst
# On bidder:
pilotctl handshake <your-prefix>-analyst "setup: ad-campaign-manager"
# On analyst:
pilotctl handshake <your-prefix>-bidder "setup: ad-campaign-manager"

# analyst <-> strategist (feedback loop)
# On analyst:
pilotctl handshake <your-prefix>-strategist "setup: ad-campaign-manager"
# On strategist:
pilotctl handshake <your-prefix>-analyst "setup: ad-campaign-manager"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-creative -- subscribe to campaign briefs:
pilotctl subscribe <your-prefix>-strategist campaign-brief

# On <your-prefix>-strategist -- publish a campaign brief:
pilotctl publish <your-prefix>-creative campaign-brief '{"campaign":"Summer Sale 2026","audience":{"age":"25-45","interests":["outdoor","fitness"]},"budget":15000,"channels":["google","meta","tiktok"],"kpis":{"target_roas":3.5,"target_ctr":0.02}}'

# On <your-prefix>-bidder -- subscribe to creative assets:
pilotctl subscribe <your-prefix>-creative creative-asset

# On <your-prefix>-creative -- publish a creative asset:
pilotctl publish <your-prefix>-bidder creative-asset '{"campaign":"Summer Sale 2026","variant":"A","headline":"Get Fit This Summer - 40% Off","format":"carousel","channels":["meta","tiktok"],"cta":"Shop Now"}'

# On <your-prefix>-analyst -- subscribe to bid results:
pilotctl subscribe <your-prefix>-bidder bid-result

# On <your-prefix>-bidder -- publish a bid result:
pilotctl publish <your-prefix>-analyst bid-result '{"campaign":"Summer Sale 2026","channel":"meta","spend":2450.00,"impressions":185000,"clicks":4100,"conversions":82,"cpc":0.60}'

# On <your-prefix>-strategist -- subscribe to performance insights:
pilotctl subscribe <your-prefix>-analyst performance-insight

# On <your-prefix>-analyst -- publish a performance insight:
pilotctl publish <your-prefix>-strategist performance-insight '{"campaign":"Summer Sale 2026","roas":4.1,"ctr":0.022,"top_channel":"meta","recommendation":"Shift 20% budget from google to tiktok based on CPA trend"}'

# On <your-prefix>-analyst -- publish external campaign report:
pilotctl publish <your-prefix>-analyst campaign-report '{"campaign":"Summer Sale 2026","period":"week_2","total_spend":8200,"total_conversions":310,"roas":3.8,"status":"on_track"}'
```
