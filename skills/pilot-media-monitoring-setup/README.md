# Media Monitoring

A multi-agent media intelligence platform that coordinates web crawling, sentiment analysis, trend detection, and automated reporting across four specialized agents. The crawler scrapes news sites, social media, blogs, forums, and press releases for brand mentions. The sentiment analyzer classifies mentions by sentiment and detects emerging narratives. The trend detector identifies viral content and spots PR crises early. The reporter generates media briefings, competitive share-of-voice reports, and crisis dashboards.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### crawler (Media Crawler)
Scrapes news sites, social media, blogs, forums, and press releases for brand mentions. Normalizes content from heterogeneous sources into structured mention objects with source metadata, timestamps, and reach estimates.

**Skills:** pilot-stream-data, pilot-cron, pilot-archive

### sentiment-analyzer (Sentiment Analyzer)
Classifies mentions by sentiment, detects emerging narratives and influencer reach. Assigns sentiment scores, identifies key opinion leaders, and flags mentions that deviate significantly from baseline sentiment.

**Skills:** pilot-event-filter, pilot-metrics, pilot-task-router

### trend-detector (Trend Detector)
Identifies viral content, tracks share of voice over time, spots PR crises early. Monitors velocity of mention growth, detects narrative shifts, and generates trend alerts when thresholds are breached.

**Skills:** pilot-dataset, pilot-alert, pilot-gossip

### reporter (Media Reporter)
Generates media briefings, competitive share-of-voice reports, and crisis dashboards. Distributes reports via Slack and webhooks to stakeholders on configurable schedules or triggered by crisis alerts.

**Skills:** pilot-slack-bridge, pilot-webhook-bridge, pilot-announce

## Data Flow

```
crawler            --> sentiment-analyzer : Raw media mentions with source metadata (port 1002)
sentiment-analyzer --> trend-detector     : Scored mentions with sentiment and reach (port 1002)
trend-detector     --> reporter           : Trend alerts and crisis warnings (port 1002)
reporter           --> external           : Media briefings via secure channel (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On crawling server
clawhub install pilot-stream-data pilot-cron pilot-archive
pilotctl set-hostname <your-prefix>-crawler

# On sentiment analysis server
clawhub install pilot-event-filter pilot-metrics pilot-task-router
pilotctl set-hostname <your-prefix>-sentiment-analyzer

# On trend detection server
clawhub install pilot-dataset pilot-alert pilot-gossip
pilotctl set-hostname <your-prefix>-trend-detector

# On reporting server
clawhub install pilot-slack-bridge pilot-webhook-bridge pilot-announce
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# crawler <-> sentiment-analyzer (media mentions)
# On crawler:
pilotctl handshake <your-prefix>-sentiment-analyzer "setup: media-monitoring"
# On sentiment-analyzer:
pilotctl handshake <your-prefix>-crawler "setup: media-monitoring"

# sentiment-analyzer <-> trend-detector (scored mentions)
# On sentiment-analyzer:
pilotctl handshake <your-prefix>-trend-detector "setup: media-monitoring"
# On trend-detector:
pilotctl handshake <your-prefix>-sentiment-analyzer "setup: media-monitoring"

# trend-detector <-> reporter (trend alerts)
# On trend-detector:
pilotctl handshake <your-prefix>-reporter "setup: media-monitoring"
# On reporter:
pilotctl handshake <your-prefix>-trend-detector "setup: media-monitoring"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-crawler -- publish a media mention:
pilotctl publish <your-prefix>-sentiment-analyzer media-mention '{"source":"reuters","url":"https://reuters.com/article/12345","headline":"Acme Corp reports record Q1 revenue","brand":"acme","reach":2400000,"published":"2026-04-10T09:15:00Z"}'

# On <your-prefix>-sentiment-analyzer -- publish a scored mention:
pilotctl publish <your-prefix>-trend-detector scored-mention '{"source":"reuters","headline":"Acme Corp reports record Q1 revenue","sentiment":"positive","score":0.87,"influencer_reach":2400000,"narratives":["earnings_beat","growth_story"]}'

# On <your-prefix>-trend-detector -- publish a trend alert:
pilotctl publish <your-prefix>-reporter trend-alert '{"brand":"acme","trend":"earnings_beat","velocity":340,"share_of_voice":0.62,"severity":"info","message":"Positive earnings coverage accelerating across major outlets"}'

# On <your-prefix>-reporter -- distribute a media briefing:
pilotctl publish <your-prefix>-reporter media-briefing '{"period":"daily","brand":"acme","total_mentions":1847,"sentiment_breakdown":{"positive":0.68,"neutral":0.24,"negative":0.08},"top_narrative":"earnings_beat","crisis_level":"none"}'
```
