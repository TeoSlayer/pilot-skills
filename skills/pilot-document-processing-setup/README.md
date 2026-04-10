# Document Processing

Deploy a document processing pipeline with 3 agents that automate document ingestion, structured data extraction, and search indexing. Each agent handles one stage of the pipeline, converting raw documents into searchable, structured data ready for downstream consumption.

**Difficulty:** Beginner | **Agents:** 3

## Roles

### ingester (Document Ingester)
Accepts documents (PDF, DOCX, images) via upload or webhook, converts to processable format, and forwards to extraction.

**Skills:** pilot-stream-data, pilot-share, pilot-archive

### extractor (Data Extractor)
Pulls structured data from documents -- tables, key-value pairs, entities, dates, and amounts. Outputs clean JSON records.

**Skills:** pilot-task-router, pilot-dataset, pilot-receipt

### indexer (Search Indexer)
Indexes extracted data for search, builds document summaries, and publishes notifications to downstream systems.

**Skills:** pilot-webhook-bridge, pilot-announce, pilot-metrics

## Data Flow

```
ingester  --> extractor : Raw documents in processable format (port 1002)
extractor --> indexer   : Extracted structured data as JSON (port 1002)
indexer   --> external  : Index notifications to downstream systems (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (document ingestion)
clawhub install pilot-stream-data pilot-share pilot-archive
pilotctl set-hostname <your-prefix>-ingester

# On server 2 (data extraction)
clawhub install pilot-task-router pilot-dataset pilot-receipt
pilotctl set-hostname <your-prefix>-extractor

# On server 3 (search indexing)
clawhub install pilot-webhook-bridge pilot-announce pilot-metrics
pilotctl set-hostname <your-prefix>-indexer
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On ingester:
pilotctl handshake <your-prefix>-extractor "setup: document-processing"
# On extractor:
pilotctl handshake <your-prefix>-ingester "setup: document-processing"

# On extractor:
pilotctl handshake <your-prefix>-indexer "setup: document-processing"
# On indexer:
pilotctl handshake <your-prefix>-extractor "setup: document-processing"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-extractor — subscribe to raw documents from ingester:
pilotctl subscribe <your-prefix>-ingester raw-document

# On <your-prefix>-ingester — publish a raw document:
pilotctl publish <your-prefix>-extractor raw-document '{"filename":"invoice-2024-003.pdf","type":"pdf","pages":2,"size_kb":184,"source":"email-attachment"}'

# On <your-prefix>-indexer — subscribe to extracted data:
pilotctl subscribe <your-prefix>-extractor extracted-data

# On <your-prefix>-extractor — publish extracted data:
pilotctl publish <your-prefix>-indexer extracted-data '{"filename":"invoice-2024-003.pdf","vendor":"Acme Corp","amount":12500.00,"currency":"USD","date":"2024-03-15","line_items":3}'

# On <your-prefix>-indexer — publish index notification:
pilotctl publish <your-prefix>-indexer index-notification '{"doc_id":"inv-2024-003","index":"invoices","status":"indexed","searchable":true,"summary":"Acme Corp invoice for $12,500"}'
```
