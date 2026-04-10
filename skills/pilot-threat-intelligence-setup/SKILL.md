---
name: pilot-threat-intelligence-setup
description: >
  Deploy a threat intelligence platform with 4 agents.

  Use this skill when:
  1. User wants to set up a threat intelligence pipeline for IOC collection and distribution
  2. User is configuring agents for threat feed aggregation, enrichment, or STIX/TAXII publishing
  3. User asks about threat analysis, IOC correlation, or MITRE ATT&CK mapping

  Do NOT use this skill when:
  - User wants a single alert notification (use pilot-alert instead)
  - User wants to stream data without threat context (use pilot-stream-data instead)
  - User only needs a webhook integration (use pilot-webhook-bridge instead)
tags:
  - pilot-protocol
  - setup
  - security
  - threat-intelligence
  - cyber
license: AGPL-3.0
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - clawhub
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Threat Intelligence Setup

Deploy 4 agents: collector, enricher, analyzer, and distributor.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| collector | `<prefix>-collector` | pilot-stream-data, pilot-cron, pilot-archive | Aggregates threat feeds from OSINT, honeypots, CVE databases |
| enricher | `<prefix>-enricher` | pilot-dataset, pilot-task-router, pilot-event-filter | Correlates IOCs, enriches with WHOIS/GeoIP, maps to MITRE |
| analyzer | `<prefix>-analyzer` | pilot-metrics, pilot-consensus, pilot-alert | Scores severity, identifies campaigns and APT groups |
| distributor | `<prefix>-distributor` | pilot-webhook-bridge, pilot-announce, pilot-audit-log | Publishes STIX/TAXII feeds, pushes IOCs to SIEM |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For collector:
clawhub install pilot-stream-data pilot-cron pilot-archive
# For enricher:
clawhub install pilot-dataset pilot-task-router pilot-event-filter
# For analyzer:
clawhub install pilot-metrics pilot-consensus pilot-alert
# For distributor:
clawhub install pilot-webhook-bridge pilot-announce pilot-audit-log
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/threat-intelligence.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

## Manifest Templates Per Role

### collector
```json
{
  "setup": "threat-intelligence", "role": "collector", "role_name": "Intel Collector",
  "hostname": "<prefix>-collector",
  "skills": {
    "pilot-stream-data": "Ingest real-time threat feeds from OSINT and honeypots.",
    "pilot-cron": "Schedule periodic CVE database and dark web scans.",
    "pilot-archive": "Store raw indicator history for retrospective analysis."
  },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-enricher", "port": 1002, "topic": "raw-ioc", "description": "Normalized IOCs from threat feeds" }],
  "handshakes_needed": ["<prefix>-enricher"]
}
```

### enricher
```json
{
  "setup": "threat-intelligence", "role": "enricher", "role_name": "Threat Enricher",
  "hostname": "<prefix>-enricher",
  "skills": {
    "pilot-dataset": "Cross-reference IOCs against known threat databases.",
    "pilot-task-router": "Route enrichment tasks to specialized lookup services.",
    "pilot-event-filter": "Filter low-confidence indicators before analysis."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-collector", "port": 1002, "topic": "raw-ioc", "description": "Raw IOCs to enrich" },
    { "direction": "send", "peer": "<prefix>-analyzer", "port": 1002, "topic": "enriched-ioc", "description": "IOCs with WHOIS, GeoIP, MITRE context" }
  ],
  "handshakes_needed": ["<prefix>-collector", "<prefix>-analyzer"]
}
```

### analyzer
```json
{
  "setup": "threat-intelligence", "role": "analyzer", "role_name": "Threat Analyzer",
  "hostname": "<prefix>-analyzer",
  "skills": {
    "pilot-metrics": "Track threat volumes, severity distribution, and response times.",
    "pilot-consensus": "Correlate multi-source verdicts for high-confidence scoring.",
    "pilot-alert": "Emit critical threat alerts for immediate action."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-enricher", "port": 1002, "topic": "enriched-ioc", "description": "Enriched IOCs to analyze" },
    { "direction": "send", "peer": "<prefix>-distributor", "port": 1002, "topic": "threat-verdict", "description": "Scored verdicts with campaign attribution" }
  ],
  "handshakes_needed": ["<prefix>-enricher", "<prefix>-distributor"]
}
```

### distributor
```json
{
  "setup": "threat-intelligence", "role": "distributor", "role_name": "Intel Distributor",
  "hostname": "<prefix>-distributor",
  "skills": {
    "pilot-webhook-bridge": "Push IOC updates to firewalls, IDS, and SIEM.",
    "pilot-announce": "Broadcast threat advisories to subscribed consumers.",
    "pilot-audit-log": "Log all published intelligence with distribution timestamps."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-analyzer", "port": 1002, "topic": "threat-verdict", "description": "Threat verdicts to distribute" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "threat-feed", "description": "STIX/TAXII feeds to security infrastructure" }
  ],
  "handshakes_needed": ["<prefix>-analyzer"]
}
```

## Data Flows

- `collector -> enricher` : raw IOCs normalized from threat feeds (port 1002)
- `enricher -> analyzer` : enriched IOCs with context and confidence scores (port 1002)
- `analyzer -> distributor` : threat verdicts with severity and campaign data (port 1002)
- `distributor -> external` : published threat feeds to security infrastructure (port 443)

## Workflow Example

```bash
# On collector -- forward raw IOC:
pilotctl --json publish <prefix>-enricher raw-ioc '{"type":"ip","value":"198.51.100.23","source":"honeypot-east","tags":["c2","cobalt-strike"]}'
# On enricher -- forward enriched IOC:
pilotctl --json publish <prefix>-analyzer enriched-ioc '{"type":"ip","value":"198.51.100.23","whois":{"asn":"AS62904","country":"RU"},"mitre":["T1071.001"],"confidence":0.87}'
# On analyzer -- send verdict:
pilotctl --json publish <prefix>-distributor threat-verdict '{"ioc":"198.51.100.23","severity":"critical","campaign":"APT-THUNDER-BEAR","action":"block"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
