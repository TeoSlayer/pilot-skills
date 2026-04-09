# ETL Data Pipeline Setup

A five-stage ETL pipeline for production data processing. Agents handle ingestion from S3 and databases, parallel transformation, data validation with quarantine for bad records, loading into target stores, and automated reporting via Slack dashboards.

**Difficulty:** Advanced | **Agents:** 5

## Roles

### ingest (Data Ingestion)
Pulls raw data from S3 buckets and databases on a cron schedule. Stages data for the transform pipeline.

**Skills:** pilot-s3-bridge, pilot-database-bridge, pilot-task-chain, pilot-cron

### transform (Data Transformer)
Processes raw data in parallel -- normalization, enrichment, deduplication. Streams results to the validator.

**Skills:** pilot-task-router, pilot-stream-data, pilot-task-parallel

### validate (Data Validator)
Checks data quality, schema conformance, and business rules. Quarantines invalid records and alerts on high error rates.

**Skills:** pilot-task-router, pilot-audit-log, pilot-alert, pilot-quarantine

### loader (Data Loader)
Writes validated data to target databases and data warehouses. Issues receipts for every successful load batch.

**Skills:** pilot-database-bridge, pilot-task-chain, pilot-receipt

### reporter (Pipeline Reporter)
Aggregates pipeline metrics, generates dashboards, and sends daily/hourly summaries to Slack. Triggers alerts on SLA breaches.

**Skills:** pilot-webhook-bridge, pilot-metrics, pilot-slack-bridge, pilot-cron

## Data Flow

```
ingest    --> transform : Raw data batches for processing (port 1001)
transform --> validate  : Transformed records for validation (port 1001)
validate  --> loader    : Validated records for loading (port 1001)
loader    --> reporter  : Load receipts and batch metrics (port 1002)
validate  --> reporter  : Validation errors and quarantine counts (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On ingestion server
clawhub install pilot-s3-bridge pilot-database-bridge pilot-task-chain pilot-cron
pilotctl set-hostname <your-prefix>-ingest

# On transform server
clawhub install pilot-task-router pilot-stream-data pilot-task-parallel
pilotctl set-hostname <your-prefix>-transform

# On validation server
clawhub install pilot-task-router pilot-audit-log pilot-alert pilot-quarantine
pilotctl set-hostname <your-prefix>-validate

# On loader server
clawhub install pilot-database-bridge pilot-task-chain pilot-receipt
pilotctl set-hostname <your-prefix>-loader

# On reporting server
clawhub install pilot-webhook-bridge pilot-metrics pilot-slack-bridge pilot-cron
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On ingest:
pilotctl handshake <your-prefix>-transform "setup: etl-data-pipeline"
# On transform:
pilotctl handshake <your-prefix>-ingest "setup: etl-data-pipeline"
# On loader:
pilotctl handshake <your-prefix>-reporter "setup: etl-data-pipeline"
# On reporter:
pilotctl handshake <your-prefix>-loader "setup: etl-data-pipeline"
# On loader:
pilotctl handshake <your-prefix>-validate "setup: etl-data-pipeline"
# On validate:
pilotctl handshake <your-prefix>-loader "setup: etl-data-pipeline"
# On reporter:
pilotctl handshake <your-prefix>-validate "setup: etl-data-pipeline"
# On validate:
pilotctl handshake <your-prefix>-reporter "setup: etl-data-pipeline"
# On transform:
pilotctl handshake <your-prefix>-validate "setup: etl-data-pipeline"
# On validate:
pilotctl handshake <your-prefix>-transform "setup: etl-data-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-ingest — trigger data ingestion and send to transformer:
pilotctl send-file <your-prefix>-transform ./data/raw/orders-2024-03.csv
pilotctl publish <your-prefix>-transform ingest-batch '{"source":"s3://data/orders","rows":50000,"batch_id":"B-1042"}'

# On <your-prefix>-transform — process and forward to validator:
pilotctl send-file <your-prefix>-validate ./data/transformed/orders-B-1042.parquet
pilotctl publish <your-prefix>-validate transform-complete '{"batch_id":"B-1042","rows_in":50000,"rows_out":49823}'

# On <your-prefix>-validate — validate and forward good records:
pilotctl send-file <your-prefix>-loader ./data/validated/orders-B-1042.parquet
pilotctl publish <your-prefix>-loader validation-passed '{"batch_id":"B-1042","valid":49700,"quarantined":123}'
pilotctl publish <your-prefix>-reporter validation-metrics '{"batch_id":"B-1042","error_rate":0.0025}'

# On <your-prefix>-loader — load and send receipt:
pilotctl publish <your-prefix>-reporter load-receipt '{"batch_id":"B-1042","rows_loaded":49700,"target":"warehouse.orders"}'
```
