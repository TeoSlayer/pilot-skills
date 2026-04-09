---
name: pilot-scientific-research-team-setup
description: >
  Deploy a scientific research team with 4 agents.

  Use this skill when:
  1. User wants to set up a collaborative research pipeline with literature review, hypothesis generation, experimentation, and reporting
  2. User is configuring agents for automated scientific discovery workflows
  3. User asks about research automation, hypothesis testing pipelines, or experiment management

  Do NOT use this skill when:
  - User wants a single literature search (use pilot-discover instead)
  - User wants to share a file between two agents (use pilot-share instead)
  - User only needs data archival (use pilot-archive instead)
tags:
  - pilot-protocol
  - setup
  - research
  - science
  - hypothesis-testing
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

# Scientific Research Team Setup

Deploy 4 agents: literature, hypothesis, experiment, and report.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| literature | `<prefix>-literature` | pilot-discover, pilot-archive, pilot-stream-data | Searches databases, builds literature reviews |
| hypothesis | `<prefix>-hypothesis` | pilot-task-router, pilot-priority-queue, pilot-dataset | Generates and ranks testable hypotheses |
| experiment | `<prefix>-experiment` | pilot-task-router, pilot-audit-log, pilot-metrics | Designs protocols, runs experiments, validates results |
| report | `<prefix>-report` | pilot-share, pilot-announce, pilot-webhook-bridge | Compiles findings into structured reports |

## Setup Procedure

**Step 1:** Ask the user which role this agent should play and what prefix to use.

**Step 2:** Install the skills for the chosen role:
```bash
# For literature:
clawhub install pilot-discover pilot-archive pilot-stream-data
# For hypothesis:
clawhub install pilot-task-router pilot-priority-queue pilot-dataset
# For experiment:
clawhub install pilot-task-router pilot-audit-log pilot-metrics
# For report:
clawhub install pilot-share pilot-announce pilot-webhook-bridge
```

**Step 3:** Set the hostname and write the manifest to `~/.pilot/setups/scientific-research-team.json`.

**Step 4:** Tell the user to initiate handshakes with the peers for their role.

## Manifest Templates Per Role

### literature
```json
{
  "setup": "scientific-research-team", "role": "literature", "role_name": "Literature Agent",
  "hostname": "<prefix>-literature",
  "skills": {
    "pilot-discover": "Search scientific databases (PubMed, arXiv, Semantic Scholar).",
    "pilot-archive": "Store retrieved papers and extracted findings for reference.",
    "pilot-stream-data": "Stream structured literature summaries to hypothesis agent."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-hypothesis", "port": 1002, "topic": "literature-synthesis", "description": "Structured reviews with gaps and citations" }
  ],
  "handshakes_needed": ["<prefix>-hypothesis"]
}
```

### hypothesis
```json
{
  "setup": "scientific-research-team", "role": "hypothesis", "role_name": "Hypothesis Agent",
  "hostname": "<prefix>-hypothesis",
  "skills": {
    "pilot-task-router": "Route hypotheses to appropriate experimental methodologies.",
    "pilot-priority-queue": "Rank hypotheses by novelty, feasibility, and impact.",
    "pilot-dataset": "Access existing datasets for preliminary pattern analysis."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-literature", "port": 1002, "topic": "literature-synthesis", "description": "Literature reviews with identified gaps" },
    { "direction": "send", "peer": "<prefix>-experiment", "port": 1002, "topic": "research-hypothesis", "description": "Ranked hypotheses with proposed protocols" }
  ],
  "handshakes_needed": ["<prefix>-literature", "<prefix>-experiment"]
}
```

### experiment
```json
{
  "setup": "scientific-research-team", "role": "experiment", "role_name": "Experiment Agent",
  "hostname": "<prefix>-experiment",
  "skills": {
    "pilot-task-router": "Manage experiment execution queues and resource allocation.",
    "pilot-audit-log": "Log all experimental parameters, runs, and raw results.",
    "pilot-metrics": "Track statistical measures -- p-values, confidence intervals, effect sizes."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-hypothesis", "port": 1002, "topic": "research-hypothesis", "description": "Hypotheses to test" },
    { "direction": "send", "peer": "<prefix>-report", "port": 1002, "topic": "experiment-result", "description": "Results with statistical validation" }
  ],
  "handshakes_needed": ["<prefix>-hypothesis", "<prefix>-report"]
}
```

### report
```json
{
  "setup": "scientific-research-team", "role": "report", "role_name": "Report Writer",
  "hostname": "<prefix>-report",
  "skills": {
    "pilot-share": "Distribute final reports to collaborators and reviewers.",
    "pilot-announce": "Broadcast publication announcements to the research network.",
    "pilot-webhook-bridge": "Push reports to external platforms (preprint servers, journals)."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-experiment", "port": 1002, "topic": "experiment-result", "description": "Experimental results to compile" },
    { "direction": "send", "peer": "external", "port": 443, "topic": "research-report", "description": "Published reports via secure channel" }
  ],
  "handshakes_needed": ["<prefix>-experiment"]
}
```

## Data Flows

- `literature -> hypothesis` : literature synthesis with gaps and citations (port 1002)
- `hypothesis -> experiment` : ranked research hypotheses with protocols (port 1002)
- `experiment -> report` : experimental results with statistical analysis (port 1002)
- `report -> external` : published research reports (port 443)

## Workflow Example

```bash
# On literature -- publish synthesis:
pilotctl --json publish <prefix>-hypothesis literature-synthesis '{"topic":"transformer scaling laws","papers_reviewed":47,"gaps":["sparse attention + MoE interaction unknown"]}'
# On hypothesis -- publish ranked hypothesis:
pilotctl --json publish <prefix>-experiment research-hypothesis '{"hypothesis_id":"H-031","statement":"Flash attention + MoE achieves superlinear scaling","novelty_score":0.87}'
# On experiment -- publish validated results:
pilotctl --json publish <prefix>-report experiment-result '{"hypothesis_id":"H-031","status":"partially_supported","p_value":0.003,"effect_size":"medium"}'
# On report -- announce publication:
pilotctl --json publish <prefix>-report research-report '{"title":"Flash Attention + MoE: Superlinear Scaling","status":"ready_for_review"}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
