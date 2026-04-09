# Scientific Research Team Setup

A collaborative research pipeline that automates the scientific method across four specialized agents. The literature agent builds structured reviews from scientific databases, the hypothesis agent identifies research gaps and generates testable hypotheses, the experiment agent designs and runs protocols with statistical validation, and the report writer compiles findings into publication-ready documents with proper citations.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### literature (Literature Agent)
Searches scientific databases, retrieves papers, extracts key findings, and builds a structured literature review with citation tracking. Identifies consensus positions, conflicting results, and methodological gaps across the corpus.

**Skills:** pilot-discover, pilot-archive, pilot-stream-data

### hypothesis (Hypothesis Agent)
Analyzes literature gaps and existing data patterns to generate testable hypotheses ranked by novelty and feasibility. Considers effect sizes, required sample sizes, and available methodologies when scoring each hypothesis.

**Skills:** pilot-task-router, pilot-priority-queue, pilot-dataset

### experiment (Experiment Agent)
Designs experimental protocols, runs simulations or analyses, collects results, and performs statistical validation. Handles parameter sweeps, controls for confounders, and computes confidence intervals and p-values for all findings.

**Skills:** pilot-task-router, pilot-audit-log, pilot-metrics

### report (Report Writer)
Compiles findings into structured research reports with proper citations, figures, and methodology sections. Formats output for journal submission, internal review, or public dissemination. Publishes final reports over a secure channel.

**Skills:** pilot-share, pilot-announce, pilot-webhook-bridge

## Data Flow

```
literature --> hypothesis : Literature synthesis with gaps and citations (port 1002)
hypothesis --> experiment : Ranked research hypotheses with protocols (port 1002)
experiment --> report     : Experimental results with statistical analysis (port 1002)
report     --> external   : Published research reports (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On literature review server
clawhub install pilot-discover pilot-archive pilot-stream-data
pilotctl set-hostname <your-prefix>-literature

# On hypothesis generation server
clawhub install pilot-task-router pilot-priority-queue pilot-dataset
pilotctl set-hostname <your-prefix>-hypothesis

# On experiment execution server
clawhub install pilot-task-router pilot-audit-log pilot-metrics
pilotctl set-hostname <your-prefix>-experiment

# On report writing server
clawhub install pilot-share pilot-announce pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-report
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# literature <-> hypothesis (literature synthesis)
# On literature:
pilotctl handshake <your-prefix>-hypothesis "setup: scientific-research-team"
# On hypothesis:
pilotctl handshake <your-prefix>-literature "setup: scientific-research-team"

# hypothesis <-> experiment (research hypotheses)
# On hypothesis:
pilotctl handshake <your-prefix>-experiment "setup: scientific-research-team"
# On experiment:
pilotctl handshake <your-prefix>-hypothesis "setup: scientific-research-team"

# experiment <-> report (experimental results)
# On experiment:
pilotctl handshake <your-prefix>-report "setup: scientific-research-team"
# On report:
pilotctl handshake <your-prefix>-experiment "setup: scientific-research-team"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-literature -- publish a literature synthesis:
pilotctl publish <your-prefix>-hypothesis literature-synthesis '{"topic":"transformer attention scaling laws","papers_reviewed":47,"key_findings":["linear attention underperforms at >1B params","flash attention reduces memory 2-4x","mixture-of-experts shows sublinear scaling"],"gaps":["no study compares all three on identical hardware","sparse attention + MoE interaction unknown"],"citations":["vaswani2017","dao2022","fedus2022"]}'

# On <your-prefix>-hypothesis -- publish a ranked hypothesis:
pilotctl publish <your-prefix>-experiment research-hypothesis '{"hypothesis_id":"H-031","statement":"Combining flash attention with top-2 MoE routing achieves superlinear throughput scaling from 1B to 10B parameters","novelty_score":0.87,"feasibility_score":0.72,"required_compute_hours":480,"methodology":"controlled_benchmark","variables":{"independent":"model_size","dependent":"throughput_per_param","controlled":["hardware","batch_size","sequence_length"]}}'

# On <your-prefix>-experiment -- publish results:
pilotctl publish <your-prefix>-report experiment-result '{"hypothesis_id":"H-031","status":"partially_supported","findings":{"scaling_exponent":1.12,"ci_95":[1.04,1.20],"p_value":0.003,"effect_size":"medium","n_runs":24},"methodology":"A/B benchmark on 8xA100 cluster","artifacts":["scaling_curve.png","raw_benchmarks.csv"]}'

# On <your-prefix>-report -- publish the final report (port 443 for secure external access):
pilotctl publish <your-prefix>-report research-report '{"title":"Flash Attention + MoE: Superlinear Scaling in Large Transformers","abstract":"We demonstrate that combining flash attention with top-2 MoE routing yields a 1.12x scaling exponent...","sections":["introduction","related_work","methodology","results","discussion","conclusion"],"citation_count":23,"status":"ready_for_review"}'
```
