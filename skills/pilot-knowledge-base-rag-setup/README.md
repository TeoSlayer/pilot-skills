# Knowledge Base (RAG) Setup

A retrieval-augmented generation pipeline. Documents are ingested from S3 or file shares, chunked and embedded in parallel, indexed into a vector store, and served to query agents. Health checks and load balancing keep the query layer responsive under load.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### rag-ingest (Document Ingestion)
Pulls documents from S3 buckets or shared directories on a schedule. Chunks large documents and forwards them to the embedder.

**Skills:** pilot-s3-bridge, pilot-share, pilot-chunk-transfer, pilot-cron

### rag-embedder (Embedding Generator)
Receives document chunks and generates vector embeddings in parallel. Forwards embeddings with metadata to the indexer.

**Skills:** pilot-task-parallel, pilot-share, pilot-metrics, pilot-task-chain

### rag-indexer (Vector Indexer)
Writes embeddings to the vector database. Maintains indexes and reports ingestion metrics. Serves as the data backend for query agents.

**Skills:** pilot-database-bridge, pilot-share, pilot-task-chain, pilot-health

### rag-query (Query Server)
Accepts search queries, retrieves relevant documents from the indexer, and returns ranked results. Load-balanced for high throughput.

**Skills:** pilot-api-gateway, pilot-health, pilot-load-balancer, pilot-metrics

## Data Flow

```
rag-ingest  --> rag-embedder : Document chunks for embedding (port 1001)
rag-embedder --> rag-indexer : Embeddings for indexing (port 1001)
rag-query   --> rag-indexer  : Retrieves relevant documents by similarity (port 1001)
rag-indexer --> rag-query    : Returns ranked document results (port 1001)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On ingestion node
clawhub install pilot-s3-bridge pilot-share pilot-chunk-transfer pilot-cron
pilotctl set-hostname <your-prefix>-rag-ingest

# On embedding node (GPU recommended)
clawhub install pilot-task-parallel pilot-share pilot-metrics pilot-task-chain
pilotctl set-hostname <your-prefix>-rag-embedder

# On indexer node
clawhub install pilot-database-bridge pilot-share pilot-task-chain pilot-health
pilotctl set-hostname <your-prefix>-rag-indexer

# On query server
clawhub install pilot-api-gateway pilot-health pilot-load-balancer pilot-metrics
pilotctl set-hostname <your-prefix>-rag-query
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# ingest <-> embedder
# On rag-ingest:
pilotctl handshake <your-prefix>-rag-embedder "rag pipeline"
# On rag-embedder:
pilotctl handshake <your-prefix>-rag-ingest "rag pipeline"

# embedder <-> indexer
# On rag-embedder:
pilotctl handshake <your-prefix>-rag-indexer "rag pipeline"
# On rag-indexer:
pilotctl handshake <your-prefix>-rag-embedder "rag pipeline"

# indexer <-> query
# On rag-indexer:
pilotctl handshake <your-prefix>-rag-query "rag pipeline"
# On rag-query:
pilotctl handshake <your-prefix>-rag-indexer "rag pipeline"
```

### 3. Verify

```bash
pilotctl trust
```
