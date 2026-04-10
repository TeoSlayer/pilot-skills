---
name: pilot-document-processing-setup
description: >
  Deploy a document processing pipeline with 3 agents that automate ingestion,
  data extraction, and search indexing.

  Use this skill when:
  1. User wants to set up document processing or data extraction pipeline
  2. User is configuring an agent as part of a document ingestion or indexing workflow
  3. User asks about OCR, PDF processing, or structured data extraction across agents

  Do NOT use this skill when:
  - User wants to share a single file (use pilot-share instead)
  - User wants to stream raw data once (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - documents
  - extraction
  - indexing
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

# Document Processing Setup

Deploy 3 agents that automate document ingestion, data extraction, and search indexing.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| ingester | `<prefix>-ingester` | pilot-stream-data, pilot-share, pilot-archive | Accepts documents, converts to processable format |
| extractor | `<prefix>-extractor` | pilot-task-router, pilot-dataset, pilot-receipt | Extracts structured data — tables, entities, amounts |
| indexer | `<prefix>-indexer` | pilot-webhook-bridge, pilot-announce, pilot-metrics | Indexes data for search, publishes to downstream systems |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# ingester:
clawhub install pilot-stream-data pilot-share pilot-archive
# extractor:
clawhub install pilot-task-router pilot-dataset pilot-receipt
# indexer:
clawhub install pilot-webhook-bridge pilot-announce pilot-metrics
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/document-processing.json << 'MANIFEST'
<USE ROLE TEMPLATE BELOW>
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### ingester
```json
{"setup":"document-processing","setup_name":"Document Processing","role":"ingester","role_name":"Document Ingester","hostname":"<prefix>-ingester","description":"Accepts documents (PDF, DOCX, images) via upload or webhook, converts to processable format.","skills":{"pilot-stream-data":"Stream raw document bytes to extractor for processing.","pilot-share":"Share converted document files with extractor.","pilot-archive":"Archive original documents for audit and reprocessing."},"peers":[{"role":"extractor","hostname":"<prefix>-extractor","description":"Receives raw documents for data extraction"}],"data_flows":[{"direction":"send","peer":"<prefix>-extractor","port":1002,"topic":"raw-document","description":"Raw documents in processable format"}],"handshakes_needed":["<prefix>-extractor"]}
```

### extractor
```json
{"setup":"document-processing","setup_name":"Document Processing","role":"extractor","role_name":"Data Extractor","hostname":"<prefix>-extractor","description":"Pulls structured data from documents — tables, key-value pairs, entities, dates, amounts.","skills":{"pilot-task-router":"Route documents to specialized extractors by type (invoice, contract, form).","pilot-dataset":"Store extraction results and training data for accuracy improvement.","pilot-receipt":"Confirm document receipt and report extraction status."},"peers":[{"role":"ingester","hostname":"<prefix>-ingester","description":"Sends raw documents"},{"role":"indexer","hostname":"<prefix>-indexer","description":"Receives extracted structured data"}],"data_flows":[{"direction":"receive","peer":"<prefix>-ingester","port":1002,"topic":"raw-document","description":"Raw documents in processable format"},{"direction":"send","peer":"<prefix>-indexer","port":1002,"topic":"extracted-data","description":"Extracted structured data as JSON"}],"handshakes_needed":["<prefix>-ingester","<prefix>-indexer"]}
```

### indexer
```json
{"setup":"document-processing","setup_name":"Document Processing","role":"indexer","role_name":"Search Indexer","hostname":"<prefix>-indexer","description":"Indexes extracted data for search, builds document summaries, publishes to downstream systems.","skills":{"pilot-webhook-bridge":"Push index events and summaries to downstream APIs and search engines.","pilot-announce":"Broadcast new document availability to interested subscribers.","pilot-metrics":"Track indexing throughput, search latency, and document counts."},"peers":[{"role":"extractor","hostname":"<prefix>-extractor","description":"Sends extracted structured data"}],"data_flows":[{"direction":"receive","peer":"<prefix>-extractor","port":1002,"topic":"extracted-data","description":"Extracted structured data as JSON"},{"direction":"send","peer":"external","port":443,"topic":"index-notification","description":"Index notifications to downstream systems"}],"handshakes_needed":["<prefix>-extractor"]}
```

## Data Flows

- `ingester -> extractor` : raw-document events (port 1002)
- `extractor -> indexer` : extracted-data events (port 1002)
- `indexer -> downstream` : index notifications via webhook (port 443)

## Handshakes

```bash
# ingester <-> extractor:
pilotctl --json handshake <prefix>-extractor "setup: document-processing"
pilotctl --json handshake <prefix>-ingester "setup: document-processing"
# extractor <-> indexer:
pilotctl --json handshake <prefix>-indexer "setup: document-processing"
pilotctl --json handshake <prefix>-extractor "setup: document-processing"
```

## Workflow Example

```bash
# On extractor — subscribe to raw documents:
pilotctl --json subscribe <prefix>-ingester raw-document
# On indexer — subscribe to extracted data:
pilotctl --json subscribe <prefix>-extractor extracted-data
# On ingester — publish a document:
pilotctl --json publish <prefix>-extractor raw-document '{"filename":"invoice-2024-003.pdf","type":"pdf","pages":2}'
# On extractor — publish extracted data:
pilotctl --json publish <prefix>-indexer extracted-data '{"filename":"invoice-2024-003.pdf","vendor":"Acme Corp","amount":12500.00}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
