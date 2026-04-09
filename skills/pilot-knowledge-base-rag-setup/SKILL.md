---
name: pilot-knowledge-base-rag-setup
description: >
  Deploy a knowledge base RAG pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up a document ingestion and retrieval pipeline
  2. User is configuring an ingestion, embedding, indexing, or query agent
  3. User asks about RAG, vector search, or knowledge base setups

  Do NOT use this skill when:
  - User wants to transfer a single file (use pilot-share instead)
  - User wants a single database query (use pilot-database-bridge instead)
tags:
  - pilot-protocol
  - setup
  - rag
  - knowledge-base
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

# Knowledge Base (RAG) Setup

Deploy 4 agents: ingest, embed, index, and query.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| ingest | `<prefix>-rag-ingest` | pilot-s3-bridge, pilot-share, pilot-chunk-transfer, pilot-cron | Pulls and chunks documents |
| embedder | `<prefix>-rag-embedder` | pilot-task-parallel, pilot-share, pilot-metrics, pilot-task-chain | Generates vector embeddings |
| indexer | `<prefix>-rag-indexer` | pilot-database-bridge, pilot-share, pilot-task-chain, pilot-health | Stores embeddings in vector DB |
| query | `<prefix>-rag-query` | pilot-api-gateway, pilot-health, pilot-load-balancer, pilot-metrics | Serves search queries |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# ingest:
clawhub install pilot-s3-bridge pilot-share pilot-chunk-transfer pilot-cron
# embedder:
clawhub install pilot-task-parallel pilot-share pilot-metrics pilot-task-chain
# indexer:
clawhub install pilot-database-bridge pilot-share pilot-task-chain pilot-health
# query:
clawhub install pilot-api-gateway pilot-health pilot-load-balancer pilot-metrics
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/knowledge-base-rag.json`.

**Step 4:** Handshake along the pipeline: ingest↔embedder, embedder↔indexer, indexer↔query.

## Manifest Templates Per Role

### ingest
```json
{
  "setup": "knowledge-base-rag", "role": "ingest", "role_name": "Document Ingestion",
  "hostname": "<prefix>-rag-ingest",
  "skills": {
    "pilot-s3-bridge": "Pull documents from S3 buckets.",
    "pilot-share": "Send document files to embedder.",
    "pilot-chunk-transfer": "Split large documents into chunks.",
    "pilot-cron": "Schedule periodic ingestion sweeps."
  },
  "data_flows": [{ "direction": "send", "peer": "<prefix>-rag-embedder", "port": 1001, "topic": "doc-ingested", "description": "Document chunks" }],
  "handshakes_needed": ["<prefix>-rag-embedder"]
}
```

### embedder
```json
{
  "setup": "knowledge-base-rag", "role": "embedder", "role_name": "Embedding Generator",
  "hostname": "<prefix>-rag-embedder",
  "skills": {
    "pilot-task-parallel": "Generate embeddings in parallel for throughput.",
    "pilot-share": "Receive docs from ingest, send embeddings to indexer.",
    "pilot-metrics": "Track embedding throughput and latency.",
    "pilot-task-chain": "Chain chunking and embedding steps."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-rag-ingest", "port": 1001, "topic": "doc-ingested", "description": "Document chunks" },
    { "direction": "send", "peer": "<prefix>-rag-indexer", "port": 1001, "topic": "embeddings-ready", "description": "Vector embeddings" }
  ],
  "handshakes_needed": ["<prefix>-rag-ingest", "<prefix>-rag-indexer"]
}
```

### indexer
```json
{
  "setup": "knowledge-base-rag", "role": "indexer", "role_name": "Vector Indexer",
  "hostname": "<prefix>-rag-indexer",
  "skills": {
    "pilot-database-bridge": "Write embeddings to vector database.",
    "pilot-share": "Receive embeddings from embedder.",
    "pilot-task-chain": "Chain indexing operations.",
    "pilot-health": "Monitor index health and query latency."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-rag-embedder", "port": 1001, "topic": "embeddings-ready", "description": "Vector embeddings" },
    { "direction": "receive", "peer": "<prefix>-rag-query", "port": 1001, "topic": "search-query", "description": "Search queries" },
    { "direction": "send", "peer": "<prefix>-rag-query", "port": 1001, "topic": "search-results", "description": "Ranked results" }
  ],
  "handshakes_needed": ["<prefix>-rag-embedder", "<prefix>-rag-query"]
}
```

### query
```json
{
  "setup": "knowledge-base-rag", "role": "query", "role_name": "Query Server",
  "hostname": "<prefix>-rag-query",
  "skills": {
    "pilot-api-gateway": "Accept search queries from external clients.",
    "pilot-health": "Monitor query endpoint health.",
    "pilot-load-balancer": "Distribute queries across indexer replicas.",
    "pilot-metrics": "Track QPS, latency, result quality."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-rag-indexer", "port": 1001, "topic": "search-query", "description": "Search queries" },
    { "direction": "receive", "peer": "<prefix>-rag-indexer", "port": 1001, "topic": "search-results", "description": "Ranked results" }
  ],
  "handshakes_needed": ["<prefix>-rag-indexer"]
}
```

## Data Flows

- `ingest → embedder` : document chunks (port 1001)
- `embedder → indexer` : vector embeddings (port 1001)
- `query ↔ indexer` : search queries and results (port 1001)

## Workflow Example

```bash
# On ingest:
pilotctl --json send-file <prefix>-rag-embedder ./docs/guide.pdf
pilotctl --json publish <prefix>-rag-embedder doc-ingested '{"doc_id":"doc-42","chunks":24}'
# On embedder:
pilotctl --json publish <prefix>-rag-indexer embeddings-ready '{"doc_id":"doc-42","vectors":24,"dims":1536}'
# On query:
pilotctl --json task submit <prefix>-rag-indexer --task '{"query":"How does auth work?","top_k":5}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
