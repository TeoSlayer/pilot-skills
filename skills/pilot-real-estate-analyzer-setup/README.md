# Real Estate Analyzer

Deploy a real estate analysis system with 4 agents that monitors property listings, calculates valuations and market metrics, generates comparable sales reports, and alerts investors to high-ROI opportunities. The pipeline covers the full deal-finding workflow from scraping to investor notification.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### scraper (Property Scraper)
Monitors MLS listings, Zillow, and Redfin feeds for new properties matching investment criteria. Normalizes data and forwards to market analysis.

**Skills:** pilot-stream-data, pilot-cron, pilot-archive

### analyzer (Market Analyzer)
Calculates property valuations, cap rates, rental yields, and appreciation trends using market data. Forwards valuation requests for comparable analysis.

**Skills:** pilot-metrics, pilot-dataset, pilot-task-router

### comparator (Comp Analyzer)
Pulls comparable sales, adjusts for property features (size, age, condition), and generates CMA (Comparative Market Analysis) reports with deal scores.

**Skills:** pilot-event-filter, pilot-share, pilot-review

### notifier (Deal Notifier)
Scores deals by ROI potential, filters by investor preferences, and alerts via Slack or email when hot opportunities are detected.

**Skills:** pilot-alert, pilot-slack-bridge, pilot-webhook-bridge

## Data Flow

```
scraper    --> analyzer    : New property listings with normalized data (port 1002)
analyzer   --> comparator  : Valuation requests with market metrics (port 1002)
comparator --> notifier    : Deal scores with CMA reports (port 1002)
notifier   --> external    : Deal alerts to Slack and email (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (property scraping)
clawhub install pilot-stream-data pilot-cron pilot-archive
pilotctl set-hostname <your-prefix>-scraper

# On server 2 (market analysis)
clawhub install pilot-metrics pilot-dataset pilot-task-router
pilotctl set-hostname <your-prefix>-analyzer

# On server 3 (comparable analysis)
clawhub install pilot-event-filter pilot-share pilot-review
pilotctl set-hostname <your-prefix>-comparator

# On server 4 (deal notifications)
clawhub install pilot-alert pilot-slack-bridge pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-notifier
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On scraper:
pilotctl handshake <your-prefix>-analyzer "setup: real-estate-analyzer"
# On analyzer:
pilotctl handshake <your-prefix>-scraper "setup: real-estate-analyzer"

# On analyzer:
pilotctl handshake <your-prefix>-comparator "setup: real-estate-analyzer"
# On comparator:
pilotctl handshake <your-prefix>-analyzer "setup: real-estate-analyzer"

# On comparator:
pilotctl handshake <your-prefix>-notifier "setup: real-estate-analyzer"
# On notifier:
pilotctl handshake <your-prefix>-comparator "setup: real-estate-analyzer"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-analyzer — subscribe to new listings from scraper:
pilotctl subscribe <your-prefix>-scraper new-listing

# On <your-prefix>-scraper — publish a new listing:
pilotctl publish <your-prefix>-analyzer new-listing '{"mls_id":"MLS-2024-78432","address":"1425 Oak Valley Dr, Austin, TX","price":485000,"sqft":2200,"beds":4,"baths":2.5,"year_built":2018,"lot_sqft":7500,"source":"redfin"}'

# On <your-prefix>-comparator — subscribe to valuation requests:
pilotctl subscribe <your-prefix>-analyzer valuation-request

# On <your-prefix>-analyzer — publish a valuation request:
pilotctl publish <your-prefix>-comparator valuation-request '{"mls_id":"MLS-2024-78432","estimated_value":502000,"cap_rate":6.8,"rental_yield":8.2,"appreciation_1yr":4.5,"price_per_sqft":220}'

# On <your-prefix>-notifier — subscribe to deal scores:
pilotctl subscribe <your-prefix>-comparator deal-score

# On <your-prefix>-comparator — publish a deal score:
pilotctl publish <your-prefix>-notifier deal-score '{"mls_id":"MLS-2024-78432","deal_score":8.7,"comps_avg_price":510000,"price_delta_pct":-4.9,"roi_estimate":12.3,"recommendation":"strong_buy","cma_report_url":"https://reports.example.com/cma-78432.pdf"}'
```
