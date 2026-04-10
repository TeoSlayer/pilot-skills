---
name: pilot-data-labeling-pipeline-setup
description: >
  Deploy a data labeling pipeline with 4 agents for ingestion, auto-labeling, quality review, and dataset export.

  Use this skill when:
  1. User wants to set up a data labeling or annotation pipeline
  2. User is configuring an agent as part of a labeling workflow
  3. User asks about ML data preparation, annotation, or training dataset generation

  Do NOT use this skill when:
  - User wants to share a single dataset (use pilot-dataset instead)
  - User wants to stream raw data without labeling (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - setup
  - data-labeling
  - machine-learning
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

# Data Labeling Pipeline Setup

Deploy 4 agents that ingest raw data, apply ML labels, review quality, and export training-ready datasets.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| ingester | `<prefix>-ingester` | pilot-s3-bridge, pilot-stream-data, pilot-task-parallel | Accepts raw data batches, splits into work items |
| labeler | `<prefix>-labeler` | pilot-task-router, pilot-dataset, pilot-metrics | Applies ML-based labels to work items |
| reviewer | `<prefix>-reviewer` | pilot-review, pilot-event-filter, pilot-alert | Samples labeled items, checks accuracy, flags disagreements |
| exporter | `<prefix>-exporter` | pilot-dataset, pilot-share, pilot-webhook-bridge | Packages approved labels into training-ready datasets |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# ingester:
clawhub install pilot-s3-bridge pilot-stream-data pilot-task-parallel
# labeler:
clawhub install pilot-task-router pilot-dataset pilot-metrics
# reviewer:
clawhub install pilot-review pilot-event-filter pilot-alert
# exporter:
clawhub install pilot-dataset pilot-share pilot-webhook-bridge
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the setup manifest:
```bash
mkdir -p ~/.pilot/setups
cat > ~/.pilot/setups/data-labeling-pipeline.json << 'MANIFEST'
{
  "setup": "data-labeling-pipeline",
  "setup_name": "Data Labeling Pipeline",
  "role": "<ROLE_ID>",
  "role_name": "<ROLE_NAME>",
  "hostname": "<prefix>-<role>",
  "description": "<ROLE_DESCRIPTION>",
  "skills": { "<skill>": "<contextual description>" },
  "peers": [ { "role": "...", "hostname": "...", "description": "..." } ],
  "data_flows": [ { "direction": "send|receive", "peer": "...", "port": 1002, "topic": "...", "description": "..." } ],
  "handshakes_needed": [ "<peer-hostname>" ]
}
MANIFEST
```

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### ingester
```json
{"setup":"data-labeling-pipeline","setup_name":"Data Labeling Pipeline","role":"ingester","role_name":"Data Ingester","hostname":"<prefix>-ingester","description":"Accepts raw data batches from S3 or webhooks. Splits into work items and distributes.","skills":{"pilot-s3-bridge":"Pull raw data batches from S3 buckets on schedule or webhook trigger.","pilot-stream-data":"Stream work items to labeler as they are split from batches.","pilot-task-parallel":"Parallelize batch splitting across available workers."},"peers":[{"role":"labeler","hostname":"<prefix>-labeler","description":"Receives work items for labeling"}],"data_flows":[{"direction":"send","peer":"<prefix>-labeler","port":1002,"topic":"work-item","description":"Work items with raw data references"}],"handshakes_needed":["<prefix>-labeler"]}
```

### labeler
```json
{"setup":"data-labeling-pipeline","setup_name":"Data Labeling Pipeline","role":"labeler","role_name":"Auto Labeler","hostname":"<prefix>-labeler","description":"Applies ML-based labels, classifications, bounding boxes, or entity tags to work items.","skills":{"pilot-task-router":"Route work items to appropriate ML models by data type.","pilot-dataset":"Store and retrieve labeled data records.","pilot-metrics":"Track labeling throughput, model confidence distributions."},"peers":[{"role":"ingester","hostname":"<prefix>-ingester","description":"Sends work items for labeling"},{"role":"reviewer","hostname":"<prefix>-reviewer","description":"Receives labeled items for quality review"}],"data_flows":[{"direction":"receive","peer":"<prefix>-ingester","port":1002,"topic":"work-item","description":"Work items with raw data references"},{"direction":"send","peer":"<prefix>-reviewer","port":1002,"topic":"labeled-item","description":"Labeled items for quality review"},{"direction":"receive","peer":"<prefix>-reviewer","port":1002,"topic":"review-feedback","description":"Feedback on rejected labels for re-labeling"}],"handshakes_needed":["<prefix>-ingester","<prefix>-reviewer"]}
```

### reviewer
```json
{"setup":"data-labeling-pipeline","setup_name":"Data Labeling Pipeline","role":"reviewer","role_name":"Quality Reviewer","hostname":"<prefix>-reviewer","description":"Samples labeled items, checks accuracy, flags disagreements, computes inter-annotator agreement.","skills":{"pilot-review":"Score labeled items against quality criteria and flag disagreements.","pilot-event-filter":"Filter low-confidence labels for priority review.","pilot-alert":"Alert on quality drops or inter-annotator agreement below threshold."},"peers":[{"role":"labeler","hostname":"<prefix>-labeler","description":"Sends labeled items for review"},{"role":"exporter","hostname":"<prefix>-exporter","description":"Receives approved labels for export"}],"data_flows":[{"direction":"receive","peer":"<prefix>-labeler","port":1002,"topic":"labeled-item","description":"Labeled items for quality review"},{"direction":"send","peer":"<prefix>-labeler","port":1002,"topic":"review-feedback","description":"Feedback for re-labeling rejected items"},{"direction":"send","peer":"<prefix>-exporter","port":1002,"topic":"approved-label","description":"Approved labels ready for packaging"}],"handshakes_needed":["<prefix>-labeler","<prefix>-exporter"]}
```

### exporter
```json
{"setup":"data-labeling-pipeline","setup_name":"Data Labeling Pipeline","role":"exporter","role_name":"Dataset Exporter","hostname":"<prefix>-exporter","description":"Packages reviewed labels into training-ready datasets (COCO, VOC, JSONL). Publishes to storage.","skills":{"pilot-dataset":"Assemble labeled items into structured dataset formats.","pilot-share":"Upload packaged datasets to S3 or shared storage.","pilot-webhook-bridge":"Notify downstream consumers when datasets are published."},"peers":[{"role":"reviewer","hostname":"<prefix>-reviewer","description":"Sends approved labels for packaging"}],"data_flows":[{"direction":"receive","peer":"<prefix>-reviewer","port":1002,"topic":"approved-label","description":"Approved labels ready for packaging"},{"direction":"send","peer":"external","port":443,"topic":"dataset-published","description":"Notification that a new dataset is available"}],"handshakes_needed":["<prefix>-reviewer"]}
```

## Data Flows

- `ingester -> labeler` : work-item events (port 1002)
- `labeler -> reviewer` : labeled-item events (port 1002)
- `reviewer -> labeler` : review-feedback events (port 1002)
- `reviewer -> exporter` : approved-label events (port 1002)
- `exporter -> external` : dataset-published notifications (port 443)

## Handshakes

```bash
# ingester <-> labeler:
pilotctl --json handshake <prefix>-labeler "setup: data-labeling-pipeline"
pilotctl --json handshake <prefix>-ingester "setup: data-labeling-pipeline"

# labeler <-> reviewer:
pilotctl --json handshake <prefix>-reviewer "setup: data-labeling-pipeline"
pilotctl --json handshake <prefix>-labeler "setup: data-labeling-pipeline"

# reviewer <-> exporter:
pilotctl --json handshake <prefix>-exporter "setup: data-labeling-pipeline"
pilotctl --json handshake <prefix>-reviewer "setup: data-labeling-pipeline"
```

## Workflow Example

```bash
# On labeler — subscribe to work items:
pilotctl --json subscribe <prefix>-ingester work-item

# On ingester — publish a work item:
pilotctl --json publish <prefix>-labeler work-item '{"batch_id":"batch-042","item_id":"img-0017","type":"image","s3_uri":"s3://raw-data/batch-042/img-0017.jpg"}'

# On reviewer — subscribe to labeled items:
pilotctl --json subscribe <prefix>-labeler labeled-item

# On exporter — subscribe to approved labels:
pilotctl --json subscribe <prefix>-reviewer approved-label
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
