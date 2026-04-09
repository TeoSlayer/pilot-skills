# ML Training Pipeline Setup

An end-to-end machine learning pipeline spanning four agents. Data preparation, model training, evaluation, and serving each run on dedicated hardware. Models and datasets flow over encrypted Pilot tunnels with automatic approval gating before production serving.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### data-prep (Data Preparation)
Cleans, validates, and transforms raw datasets. Shares processed data with the trainer via dataset transfer.

**Skills:** pilot-dataset, pilot-share, pilot-task-chain

### trainer (Model Trainer)
Receives prepared datasets, runs training jobs, tracks metrics, and shares trained model artifacts with the evaluator.

**Skills:** pilot-dataset, pilot-model-share, pilot-metrics, pilot-task-chain

### evaluator (Model Evaluator)
Scores trained models against benchmarks, compares with baselines, and gates promotion to serving via review approval.

**Skills:** pilot-model-share, pilot-metrics, pilot-review, pilot-task-chain

### serving (Model Server)
Loads approved models, serves inference requests, monitors health, and load-balances across replicas.

**Skills:** pilot-model-share, pilot-health, pilot-webhook-bridge, pilot-load-balancer

## Data Flow

```
data-prep --> trainer   : Cleaned datasets for training (port 1001)
trainer   --> evaluator : Trained model checkpoints and metrics (port 1001)
evaluator --> serving   : Approved models for production serving (port 1001)
serving   --> evaluator : Inference metrics for drift detection (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On data processing node
clawhub install pilot-dataset pilot-share pilot-task-chain
pilotctl set-hostname <your-prefix>-data-prep

# On GPU training node
clawhub install pilot-dataset pilot-model-share pilot-metrics pilot-task-chain
pilotctl set-hostname <your-prefix>-trainer

# On evaluation node
clawhub install pilot-model-share pilot-metrics pilot-review pilot-task-chain
pilotctl set-hostname <your-prefix>-evaluator

# On serving node
clawhub install pilot-model-share pilot-health pilot-webhook-bridge pilot-load-balancer
pilotctl set-hostname <your-prefix>-serving
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On data-prep:
pilotctl handshake <your-prefix>-trainer "setup: ml-training-pipeline"
# On trainer:
pilotctl handshake <your-prefix>-data-prep "setup: ml-training-pipeline"
# On evaluator:
pilotctl handshake <your-prefix>-serving "setup: ml-training-pipeline"
# On serving:
pilotctl handshake <your-prefix>-evaluator "setup: ml-training-pipeline"
# On evaluator:
pilotctl handshake <your-prefix>-trainer "setup: ml-training-pipeline"
# On trainer:
pilotctl handshake <your-prefix>-evaluator "setup: ml-training-pipeline"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-data-prep — send cleaned dataset to trainer:
pilotctl send-file <your-prefix>-trainer ./datasets/training-v5.parquet
pilotctl publish <your-prefix>-trainer dataset-ready '{"name":"training-v5","rows":150000,"features":64}'

# On <your-prefix>-trainer — send model checkpoint and metrics:
pilotctl send-file <your-prefix>-evaluator ./models/resnet-v5-epoch20.pt
pilotctl publish <your-prefix>-evaluator training-complete '{"model":"resnet-v5","loss":0.023,"accuracy":0.967,"epochs":20}'

# On <your-prefix>-evaluator — approve and promote to serving:
pilotctl send-file <your-prefix>-serving ./models/resnet-v5-epoch20.pt
pilotctl publish <your-prefix>-serving model-approved '{"model":"resnet-v5","benchmark":0.971,"approved":true}'

# On <your-prefix>-serving — report inference metrics:
pilotctl publish <your-prefix>-evaluator inference-metrics '{"model":"resnet-v5","qps":1200,"p99_ms":45,"drift":0.003}'
```
