---
name: pilot-ml-training-pipeline-setup
description: >
  Deploy an end-to-end ML training pipeline with 4 agents.

  Use this skill when:
  1. User wants to set up a machine learning training pipeline
  2. User is configuring a data prep, training, evaluation, or serving agent
  3. User asks about ML model lifecycle management across agents

  Do NOT use this skill when:
  - User wants to share a single model file (use pilot-model-share instead)
  - User wants to transfer a dataset (use pilot-dataset instead)
tags:
  - pilot-protocol
  - setup
  - machine-learning
  - pipeline
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

# ML Training Pipeline Setup

Deploy 4 agents spanning data prep, training, evaluation, and serving.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| data-prep | `<prefix>-data-prep` | pilot-dataset, pilot-share, pilot-task-chain | Cleans and transforms datasets |
| trainer | `<prefix>-trainer` | pilot-dataset, pilot-model-share, pilot-metrics, pilot-task-chain | Trains models, tracks metrics |
| evaluator | `<prefix>-evaluator` | pilot-model-share, pilot-metrics, pilot-review, pilot-task-chain | Evaluates and gates promotion |
| serving | `<prefix>-serving` | pilot-model-share, pilot-health, pilot-webhook-bridge, pilot-load-balancer, pilot-metrics | Serves inference requests |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For data-prep:
clawhub install pilot-dataset pilot-share pilot-task-chain
# For trainer:
clawhub install pilot-dataset pilot-model-share pilot-metrics pilot-task-chain
# For evaluator:
clawhub install pilot-model-share pilot-metrics pilot-review pilot-task-chain
# For serving:
clawhub install pilot-model-share pilot-health pilot-webhook-bridge pilot-load-balancer pilot-metrics
```

**Step 3:** Set the hostname:
```bash
pilotctl --json set-hostname <prefix>-<role>
```

**Step 4:** Write the role-specific JSON manifest to `~/.pilot/setups/ml-training-pipeline.json`.

**Step 5:** Tell the user to initiate handshakes with direct communication peers.

## Manifest Templates Per Role

### data-prep
```json
{
  "setup": "ml-training-pipeline", "role": "data-prep", "role_name": "Data Preparation",
  "hostname": "<prefix>-data-prep",
  "description": "Cleans, validates, and transforms raw datasets. Shares processed data with the trainer.",
  "skills": {
    "pilot-dataset": "Exchange structured datasets with schema negotiation.",
    "pilot-share": "Send cleaned dataset files to <prefix>-trainer.",
    "pilot-task-chain": "Chain data prep steps into sequential pipeline."
  },
  "peers": [{ "role": "trainer", "hostname": "<prefix>-trainer", "description": "Receives prepared datasets" }],
  "data_flows": [{ "direction": "send", "peer": "<prefix>-trainer", "port": 1001, "topic": "dataset-ready", "description": "Cleaned datasets" }],
  "handshakes_needed": ["<prefix>-trainer"]
}
```

### trainer
```json
{
  "setup": "ml-training-pipeline", "role": "trainer", "role_name": "Model Trainer",
  "hostname": "<prefix>-trainer",
  "description": "Receives prepared datasets, runs training jobs, tracks metrics, and shares trained model artifacts.",
  "skills": {
    "pilot-dataset": "Receive prepared datasets from data-prep.",
    "pilot-model-share": "Send trained model checkpoints to evaluator.",
    "pilot-metrics": "Track and publish training loss, accuracy, epochs.",
    "pilot-task-chain": "Chain training steps sequentially."
  },
  "peers": [
    { "role": "data-prep", "hostname": "<prefix>-data-prep", "description": "Sends prepared datasets" },
    { "role": "evaluator", "hostname": "<prefix>-evaluator", "description": "Receives trained models" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-data-prep", "port": 1001, "topic": "dataset-ready", "description": "Cleaned datasets" },
    { "direction": "send", "peer": "<prefix>-evaluator", "port": 1001, "topic": "training-complete", "description": "Model checkpoints and metrics" }
  ],
  "handshakes_needed": ["<prefix>-data-prep", "<prefix>-evaluator"]
}
```

### evaluator
```json
{
  "setup": "ml-training-pipeline", "role": "evaluator", "role_name": "Model Evaluator",
  "hostname": "<prefix>-evaluator",
  "description": "Scores trained models against benchmarks and gates promotion to serving.",
  "skills": {
    "pilot-model-share": "Receive models from trainer, promote approved models to serving.",
    "pilot-metrics": "Compare benchmarks, detect drift.",
    "pilot-review": "Gate model promotion with approval workflow.",
    "pilot-task-chain": "Chain evaluation steps."
  },
  "peers": [
    { "role": "trainer", "hostname": "<prefix>-trainer", "description": "Sends trained models" },
    { "role": "serving", "hostname": "<prefix>-serving", "description": "Receives approved models" }
  ],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-trainer", "port": 1001, "topic": "training-complete", "description": "Model checkpoints" },
    { "direction": "send", "peer": "<prefix>-serving", "port": 1001, "topic": "model-approved", "description": "Approved models" },
    { "direction": "receive", "peer": "<prefix>-serving", "port": 1002, "topic": "inference-metrics", "description": "Drift detection data" }
  ],
  "handshakes_needed": ["<prefix>-trainer", "<prefix>-serving"]
}
```

### serving
```json
{
  "setup": "ml-training-pipeline", "role": "serving", "role_name": "Model Server",
  "hostname": "<prefix>-serving",
  "description": "Loads approved models, serves inference, monitors health, and load-balances.",
  "skills": {
    "pilot-model-share": "Receive approved models from evaluator.",
    "pilot-health": "Monitor inference endpoint health and latency.",
    "pilot-webhook-bridge": "Trigger external alerts on serving failures.",
    "pilot-load-balancer": "Distribute inference requests across replicas.",
    "pilot-metrics": "Report QPS, latency, drift metrics to evaluator."
  },
  "peers": [{ "role": "evaluator", "hostname": "<prefix>-evaluator", "description": "Sends approved models, receives metrics" }],
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-evaluator", "port": 1001, "topic": "model-approved", "description": "Approved models" },
    { "direction": "send", "peer": "<prefix>-evaluator", "port": 1002, "topic": "inference-metrics", "description": "Inference metrics for drift" }
  ],
  "handshakes_needed": ["<prefix>-evaluator"]
}
```

## Data Flows

- `data-prep → trainer` : cleaned datasets (port 1001)
- `trainer → evaluator` : model checkpoints and metrics (port 1001)
- `evaluator → serving` : approved models (port 1001)
- `serving → evaluator` : inference metrics for drift detection (port 1002)

## Workflow Example

```bash
# On data-prep:
pilotctl --json send-file <prefix>-trainer ./datasets/training-v5.parquet
pilotctl --json publish <prefix>-trainer dataset-ready '{"name":"training-v5","rows":150000}'
# On trainer:
pilotctl --json send-file <prefix>-evaluator ./models/resnet-v5.pt
pilotctl --json publish <prefix>-evaluator training-complete '{"model":"resnet-v5","accuracy":0.967}'
# On evaluator:
pilotctl --json send-file <prefix>-serving ./models/resnet-v5.pt
pilotctl --json publish <prefix>-serving model-approved '{"model":"resnet-v5","benchmark":0.971}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
