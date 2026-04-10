# Data Labeling Pipeline

Deploy a distributed data labeling pipeline with 4 agents that ingests raw data, applies ML-based labels, reviews quality, and exports training-ready datasets. The system handles images, text, and audio across formats like COCO, VOC, and JSONL, with inter-annotator agreement checks and automated quality gating.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### ingester (Data Ingester)
Accepts raw data batches (images, text, audio) from S3 or webhooks. Splits into work items and distributes them to labelers for processing.

**Skills:** pilot-s3-bridge, pilot-stream-data, pilot-task-parallel

### labeler (Auto Labeler)
Applies ML-based labels, classifications, bounding boxes, or entity tags to work items. Publishes labeled items for quality review.

**Skills:** pilot-task-router, pilot-dataset, pilot-metrics

### reviewer (Quality Reviewer)
Samples labeled items, checks accuracy, flags disagreements, and computes inter-annotator agreement. Routes feedback to labelers or approved items to export.

**Skills:** pilot-review, pilot-event-filter, pilot-alert

### exporter (Dataset Exporter)
Packages reviewed labels into training-ready datasets (COCO, VOC, JSONL). Publishes completed datasets to storage and notifies downstream consumers.

**Skills:** pilot-dataset, pilot-share, pilot-webhook-bridge

## Data Flow

```
ingester --> labeler   : Work items with raw data references (port 1002)
labeler  --> reviewer  : Labeled items for quality review (port 1002)
reviewer --> labeler   : Review feedback for re-labeling (port 1002)
reviewer --> exporter  : Approved labels ready for packaging (port 1002)
exporter --> external  : Dataset published notifications (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (data ingestion)
clawhub install pilot-s3-bridge pilot-stream-data pilot-task-parallel
pilotctl set-hostname <your-prefix>-ingester

# On server 2 (auto labeling)
clawhub install pilot-task-router pilot-dataset pilot-metrics
pilotctl set-hostname <your-prefix>-labeler

# On server 3 (quality review)
clawhub install pilot-review pilot-event-filter pilot-alert
pilotctl set-hostname <your-prefix>-reviewer

# On server 4 (dataset export)
clawhub install pilot-dataset pilot-share pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-exporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On ingester:
pilotctl handshake <your-prefix>-labeler "setup: data-labeling-pipeline"
# On labeler:
pilotctl handshake <your-prefix>-ingester "setup: data-labeling-pipeline"

# On labeler:
pilotctl handshake <your-prefix>-reviewer "setup: data-labeling-pipeline"
# On reviewer:
pilotctl handshake <your-prefix>-labeler "setup: data-labeling-pipeline"

# On reviewer:
pilotctl handshake <your-prefix>-exporter "setup: data-labeling-pipeline"
# On exporter:
pilotctl handshake <your-prefix>-reviewer "setup: data-labeling-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-labeler — subscribe to work items from ingester:
pilotctl subscribe <your-prefix>-ingester work-item

# On <your-prefix>-ingester — publish a work item:
pilotctl publish <your-prefix>-labeler work-item '{"batch_id":"batch-042","item_id":"img-0017","type":"image","s3_uri":"s3://raw-data/batch-042/img-0017.jpg","labels_requested":["object_detection","classification"]}'

# On <your-prefix>-reviewer — subscribe to labeled items:
pilotctl subscribe <your-prefix>-labeler labeled-item

# On <your-prefix>-labeler — publish a labeled item:
pilotctl publish <your-prefix>-reviewer labeled-item '{"item_id":"img-0017","labels":[{"class":"vehicle","bbox":[120,45,380,290],"confidence":0.94}],"model":"yolov8-custom"}'

# On <your-prefix>-exporter — subscribe to approved labels:
pilotctl subscribe <your-prefix>-reviewer approved-label

# On <your-prefix>-reviewer — approve and forward:
pilotctl publish <your-prefix>-exporter approved-label '{"item_id":"img-0017","labels":[{"class":"vehicle","bbox":[120,45,380,290]}],"reviewer":"auto-qa","agreement_score":0.92}'
```
