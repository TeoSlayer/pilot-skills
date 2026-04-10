# Threat Intelligence

A threat intelligence platform that aggregates indicators of compromise from multiple sources, enriches them with contextual data, analyzes threat severity and campaign attribution, and distributes actionable intelligence to security infrastructure. The collector ingests raw feeds, the enricher correlates and contextualizes IOCs, the analyzer scores threats and maps to frameworks, and the distributor pushes formatted intelligence to downstream consumers.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### collector (Intel Collector)
Aggregates threat feeds from OSINT sources, dark web monitors, CVE databases, and honeypot networks. Normalizes indicators into a common format and deduplicates across sources before forwarding for enrichment.

**Skills:** pilot-stream-data, pilot-cron, pilot-archive

### enricher (Threat Enricher)
Correlates IOCs across multiple sources, enriches with WHOIS lookups, GeoIP data, passive DNS history, and maps indicators to the MITRE ATT&CK framework. Adds confidence scores based on source reliability.

**Skills:** pilot-dataset, pilot-task-router, pilot-event-filter

### analyzer (Threat Analyzer)
Scores threat severity using multi-factor analysis, identifies active campaigns and APT group attribution, generates threat profiles with kill chain mapping, and triggers alerts for critical threats.

**Skills:** pilot-metrics, pilot-consensus, pilot-alert

### distributor (Intel Distributor)
Publishes formatted threat intelligence as STIX/TAXII feeds, pushes IOC updates to firewalls and IDS/IPS systems, distributes indicators to SIEM platforms, and maintains an audit trail of all published intelligence.

**Skills:** pilot-webhook-bridge, pilot-announce, pilot-audit-log

## Data Flow

```
collector   --> enricher    : Raw IOCs normalized from threat feeds (port 1002)
enricher    --> analyzer    : Enriched IOCs with context and confidence scores (port 1002)
analyzer    --> distributor : Threat verdicts with severity and campaign data (port 1002)
distributor --> external    : Published threat feeds to security infrastructure (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On intel collection node
clawhub install pilot-stream-data pilot-cron pilot-archive
pilotctl set-hostname <your-prefix>-collector

# On enrichment node
clawhub install pilot-dataset pilot-task-router pilot-event-filter
pilotctl set-hostname <your-prefix>-enricher

# On analysis node
clawhub install pilot-metrics pilot-consensus pilot-alert
pilotctl set-hostname <your-prefix>-analyzer

# On distribution node
clawhub install pilot-webhook-bridge pilot-announce pilot-audit-log
pilotctl set-hostname <your-prefix>-distributor
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# collector <-> enricher (raw IOCs)
# On collector:
pilotctl handshake <your-prefix>-enricher "setup: threat-intelligence"
# On enricher:
pilotctl handshake <your-prefix>-collector "setup: threat-intelligence"

# enricher <-> analyzer (enriched IOCs)
# On enricher:
pilotctl handshake <your-prefix>-analyzer "setup: threat-intelligence"
# On analyzer:
pilotctl handshake <your-prefix>-enricher "setup: threat-intelligence"

# analyzer <-> distributor (threat verdicts)
# On analyzer:
pilotctl handshake <your-prefix>-distributor "setup: threat-intelligence"
# On distributor:
pilotctl handshake <your-prefix>-analyzer "setup: threat-intelligence"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-collector -- forward raw IOC to enricher:
pilotctl publish <your-prefix>-enricher raw-ioc '{"type":"ip","value":"198.51.100.23","source":"honeypot-east","first_seen":"2026-04-10T08:15:00Z","tags":["c2","cobalt-strike"],"feed":"osint-honeypot"}'

# On <your-prefix>-enricher -- forward enriched IOC to analyzer:
pilotctl publish <your-prefix>-analyzer enriched-ioc '{"type":"ip","value":"198.51.100.23","whois":{"asn":"AS62904","org":"ShadowHost Ltd","country":"RU"},"geoip":{"lat":55.75,"lon":37.62},"mitre":["T1071.001","T1059.001"],"confidence":0.87,"sources_count":4}'

# On <your-prefix>-analyzer -- send threat verdict to distributor:
pilotctl publish <your-prefix>-distributor threat-verdict '{"ioc":"198.51.100.23","severity":"critical","campaign":"APT-THUNDER-BEAR","apt_group":"TA505","kill_chain_phase":"command-and-control","action":"block","ttl_hours":168}'

# On <your-prefix>-distributor -- subscribe to verdicts:
pilotctl subscribe <your-prefix>-analyzer threat-verdict
```
