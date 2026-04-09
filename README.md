# Pilot Protocol Skills

[![Tests](https://github.com/TeoSlayer/pilot-skills/actions/workflows/test.yml/badge.svg)](https://github.com/TeoSlayer/pilot-skills/actions/workflows/test.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-81-22c55e)](https://teoslayer.github.io/pilot-skills/)
[![ClawHub](https://img.shields.io/badge/ClawHub-teoslayer-orange)](https://clawhub.ai/teoslayer/pilot-protocol)

A collection of agent skills built on [Pilot Protocol](https://pilotprotocol.network) — the overlay network stack for AI agents.

Each skill wraps `pilotctl` to provide a focused capability: messaging, file sync, trust management, task routing, swarm coordination, and more. All skills depend on the core `pilot-protocol` skill and a running Pilot daemon.

**[Browse the catalog](https://teoslayer.github.io/pilot-skills/)** &middot; **[Skill Zoo](https://pilotprotocol.network/for/skills)** &middot; **[ClawHub](https://clawhub.ai/teoslayer/pilot-protocol)**

## Quick Start

```bash
# Install Pilot Protocol
curl -fsSL https://pilotprotocol.network/install.sh | sh

# Start the daemon
pilotctl daemon start --hostname my-agent --email you@example.com

# Install any skill
clawhub install pilot-chat
```

## Skills

### Communication

| Skill | Description |
|-------|-------------|
| [pilot-chat](skills/pilot-chat/) | Send and receive text messages between agents |
| [pilot-broadcast](skills/pilot-broadcast/) | Publish messages to all trusted peers on a topic |
| [pilot-inbox](skills/pilot-inbox/) | Unified inbox — messages, files, tasks, trust requests in one view |
| [pilot-relay](skills/pilot-relay/) | Store-and-forward messaging for offline peers |
| [pilot-group-chat](skills/pilot-group-chat/) | Multi-agent group conversations with membership management |
| [pilot-announce](skills/pilot-announce/) | One-to-many announcements with read receipts |
| [pilot-voice-memo](skills/pilot-voice-memo/) | Send audio file messages between agents |
| [pilot-translate](skills/pilot-translate/) | Auto-translate messages between agents using different languages |
| [pilot-compress](skills/pilot-compress/) | Transparent compression for large messages |
| [pilot-priority-queue](skills/pilot-priority-queue/) | Priority-based message delivery with urgency levels |
| [pilot-receipt](skills/pilot-receipt/) | Delivery and read receipts for messages |
| [pilot-thread](skills/pilot-thread/) | Threaded conversations with context tracking |

### File Transfer & Data

| Skill | Description |
|-------|-------------|
| [pilot-sync](skills/pilot-sync/) | Bidirectional file synchronization between agents |
| [pilot-share](skills/pilot-share/) | One-click file sharing with progress and retry |
| [pilot-dropbox](skills/pilot-dropbox/) | Shared folder that auto-syncs between peers |
| [pilot-stream-data](skills/pilot-stream-data/) | Real-time NDJSON data streaming over persistent connections |
| [pilot-chunk-transfer](skills/pilot-chunk-transfer/) | Large file transfer with chunking and resume |
| [pilot-dataset](skills/pilot-dataset/) | Exchange structured datasets with schema negotiation |
| [pilot-model-share](skills/pilot-model-share/) | Distribute ML model files with model card metadata |
| [pilot-backup](skills/pilot-backup/) | Automated backup of agent state to a trusted peer |
| [pilot-clipboard](skills/pilot-clipboard/) | Shared clipboard between agents |
| [pilot-archive](skills/pilot-archive/) | Index and search historical data exchanges |

### Trust & Security

| Skill | Description |
|-------|-------------|
| [pilot-auto-trust](skills/pilot-auto-trust/) | Automatic trust management with configurable policies |
| [pilot-trust-circle](skills/pilot-trust-circle/) | Named trust groups with automatic mutual handshakes |
| [pilot-verify](skills/pilot-verify/) | Verify agent identity and reputation before interacting |
| [pilot-blocklist](skills/pilot-blocklist/) | Maintain and share blocklists of untrusted agents |
| [pilot-audit-log](skills/pilot-audit-log/) | Comprehensive audit trail of all protocol activity |
| [pilot-keychain](skills/pilot-keychain/) | Secure credential exchange with auto-expiry |
| [pilot-reputation](skills/pilot-reputation/) | Advanced reputation analytics and trend visualization |
| [pilot-watchdog](skills/pilot-watchdog/) | Security monitoring for suspicious network patterns |
| [pilot-quarantine](skills/pilot-quarantine/) | Isolate suspicious agents pending investigation |
| [pilot-certificate](skills/pilot-certificate/) | Issue and verify Ed25519-signed capability certificates |

### Task & Workflow

| Skill | Description |
|-------|-------------|
| [pilot-task-router](skills/pilot-task-router/) | Route tasks to the best agent by capability and reputation |
| [pilot-task-monitor](skills/pilot-task-monitor/) | Real-time dashboard for task status and polo score tracking |
| [pilot-task-chain](skills/pilot-task-chain/) | Chain tasks into sequential pipelines across agents |
| [pilot-task-parallel](skills/pilot-task-parallel/) | Fan-out tasks to multiple agents and merge results |
| [pilot-task-retry](skills/pilot-task-retry/) | Automatic retry with exponential backoff and fallback targets |
| [pilot-task-template](skills/pilot-task-template/) | Reusable task templates with placeholder substitution |
| [pilot-cron](skills/pilot-cron/) | Scheduled recurring task submission |
| [pilot-workflow](skills/pilot-workflow/) | YAML-defined multi-step workflows with orchestration |
| [pilot-auction](skills/pilot-auction/) | Task auction — agents bid, requester selects best offer |
| [pilot-escrow](skills/pilot-escrow/) | Polo score escrow for verified task completion |
| [pilot-sla](skills/pilot-sla/) | Service-level agreement enforcement with auto-penalties |
| [pilot-review](skills/pilot-review/) | Peer review system for task results before acceptance |

### Discovery & Network

| Skill | Description |
|-------|-------------|
| [pilot-discover](skills/pilot-discover/) | Advanced agent discovery by tags, polo score, and status |
| [pilot-directory](skills/pilot-directory/) | Local directory of known agents with cached metadata |
| [pilot-network-map](skills/pilot-network-map/) | Visualize network topology, trust graphs, and latency |
| [pilot-dns](skills/pilot-dns/) | Human-friendly naming with aliases and namespaces |
| [pilot-health](skills/pilot-health/) | Network health monitoring with latency and reachability checks |
| [pilot-announce-capabilities](skills/pilot-announce-capabilities/) | Broadcast structured capability manifests to the network |
| [pilot-matchmaker](skills/pilot-matchmaker/) | Match agents with complementary capabilities |
| [pilot-mesh-status](skills/pilot-mesh-status/) | Comprehensive mesh status — peers, encryption, relay, bandwidth |

### Event & Pub/Sub

| Skill | Description |
|-------|-------------|
| [pilot-event-bus](skills/pilot-event-bus/) | Multi-agent event aggregation on shared topics |
| [pilot-event-filter](skills/pilot-event-filter/) | Filter and transform events before delivery |
| [pilot-event-replay](skills/pilot-event-replay/) | Record and replay event streams for debugging |
| [pilot-alert](skills/pilot-alert/) | Configurable alerting on event patterns |
| [pilot-metrics](skills/pilot-metrics/) | Collect and aggregate agent metrics |
| [pilot-event-log](skills/pilot-event-log/) | Persistent NDJSON event logging with rotation |
| [pilot-webhook-bridge](skills/pilot-webhook-bridge/) | Forward Pilot events to HTTP webhooks (Slack, Discord, etc.) |
| [pilot-presence](skills/pilot-presence/) | Real-time online/offline/busy presence tracking |

### Integration & Bridge

| Skill | Description |
|-------|-------------|
| [pilot-mcp-bridge](skills/pilot-mcp-bridge/) | MCP server wrapping the Pilot daemon for OpenClaw/Claude Code |
| [pilot-a2a-bridge](skills/pilot-a2a-bridge/) | Bridge A2A protocol messages over Pilot tunnels |
| [pilot-http-proxy](skills/pilot-http-proxy/) | Route HTTP requests through Pilot tunnels |
| [pilot-slack-bridge](skills/pilot-slack-bridge/) | Bidirectional Slack channel bridge |
| [pilot-discord-bridge](skills/pilot-discord-bridge/) | Bidirectional Discord server bridge |
| [pilot-email-bridge](skills/pilot-email-bridge/) | Send and receive emails via Pilot |
| [pilot-github-bridge](skills/pilot-github-bridge/) | GitHub webhook events as Pilot events |
| [pilot-database-bridge](skills/pilot-database-bridge/) | Query remote databases through Pilot tunnels |
| [pilot-s3-bridge](skills/pilot-s3-bridge/) | Access cloud storage through a bridge agent |
| [pilot-api-gateway](skills/pilot-api-gateway/) | Expose local APIs to the Pilot network |

### Swarm & Coordination

| Skill | Description |
|-------|-------------|
| [pilot-swarm-join](skills/pilot-swarm-join/) | Join or create agent swarms with auto-discovery |
| [pilot-consensus](skills/pilot-consensus/) | Distributed voting and agreement among agents |
| [pilot-leader-election](skills/pilot-leader-election/) | Elect a coordinator with automatic failover |
| [pilot-load-balancer](skills/pilot-load-balancer/) | Distribute tasks across worker pools |
| [pilot-map-reduce](skills/pilot-map-reduce/) | Distributed map-reduce over agent swarms |
| [pilot-gossip](skills/pilot-gossip/) | Gossip protocol for eventually-consistent shared state |
| [pilot-heartbeat-monitor](skills/pilot-heartbeat-monitor/) | Detect agent failures and trigger redistribution |
| [pilot-role-assign](skills/pilot-role-assign/) | Assign and manage roles within a swarm |
| [pilot-swarm-config](skills/pilot-swarm-config/) | Distributed configuration management for swarms |
| [pilot-formation](skills/pilot-formation/) | Deploy predefined topologies — star, ring, mesh, tree |

### Deployment Orgs

Pre-built multi-agent deployment recipes. Each org deploys 3-5 agents with defined roles, trust relationships, and data flows.

**Beginner**

| Org | Agents | Description |
|-----|--------|-------------|
| [Fleet Health Monitor](skills/pilot-fleet-health-monitor-setup/) | 3 | Monitor servers, detect anomalies, alert humans |
| [Chat Collaboration Hub](skills/pilot-chat-collaboration-hub-setup/) | 4 | Multi-agent chat with moderation, translation, and archiving |
| [Content Marketing Pipeline](skills/pilot-content-marketing-pipeline-setup/) | 3 | Research, write, and publish content |
| [Customer Support Triage](skills/pilot-customer-support-triage-setup/) | 3 | Classify, resolve, and escalate support tickets |
| [Social Media Manager](skills/pilot-social-media-manager-setup/) | 3 | Plan, create, and analyze social media content |

**Intermediate**

| Org | Agents | Description |
|-----|--------|-------------|
| [CI/CD Pipeline](skills/pilot-ci-cd-pipeline-setup/) | 3 | Build, test, and deploy with zero central server |
| [ML Training Pipeline](skills/pilot-ml-training-pipeline-setup/) | 4 | End-to-end ML: data prep, training, evaluation, serving |
| [Multi-Region Content Sync](skills/pilot-multi-region-content-sync-setup/) | 4 | Origin + edge node content distribution |
| [Knowledge Base RAG](skills/pilot-knowledge-base-rag-setup/) | 4 | Ingest, embed, index, and query documents |
| [MCP Bridge Fleet](skills/pilot-mcp-bridge-fleet-setup/) | 3 | Bridge MCP and A2A protocols over Pilot tunnels |
| [Cloud Cost Optimizer](skills/pilot-cloud-cost-optimizer-setup/) | 4 | Scan, analyze, optimize, and report cloud spending |
| [Legal Contract Review](skills/pilot-legal-contract-review-setup/) | 3 | Extract clauses, assess risk, summarize contracts |
| [AI Tutoring System](skills/pilot-ai-tutoring-system-setup/) | 3 | Curate lessons, tutor learners, assess knowledge gaps |
| [Smart Home Coordinator](skills/pilot-smart-home-coordinator-setup/) | 4 | Collect sensor data, coordinate devices, display status |

**Advanced**

| Org | Agents | Description |
|-----|--------|-------------|
| [Incident Response](skills/pilot-incident-response-setup/) | 4 | Detect, triage, remediate, and notify on incidents |
| [Dev Team Assistants](skills/pilot-dev-team-assistants-setup/) | 4 | Code review, test running, doc writing, coordination |
| [ETL Data Pipeline](skills/pilot-etl-data-pipeline-setup/) | 5 | Five-stage data pipeline: ingest, transform, validate, load, report |
| [Swarm Task Farm](skills/pilot-swarm-task-farm-setup/) | 5 | Self-organizing compute swarm with leader election |
| [Security Operations Center](skills/pilot-security-operations-center-setup/) | 4 | Log collection, threat analysis, enforcement, dashboard |
| [Agent Marketplace](skills/pilot-agent-marketplace-setup/) | 4 | Decentralized agent marketplace with escrow |
| [Backup & Disaster Recovery](skills/pilot-backup-disaster-recovery-setup/) | 4 | Scheduled backups, offsite replication, restore testing |
| [Compliance & Governance](skills/pilot-compliance-governance-setup/) | 4 | Policy enforcement, auditing, certification, reporting |
| [Supply Chain Orchestrator](skills/pilot-supply-chain-orchestrator-setup/) | 4 | Inventory, routing, procurement, compliance |
| [Financial Trading Desk](skills/pilot-financial-trading-desk-setup/) | 4 | Market analysis, sentiment, risk management, execution |
| [Scientific Research Team](skills/pilot-scientific-research-team-setup/) | 4 | Literature review, hypothesis, experiments, reports |
| [Fraud Detection Pipeline](skills/pilot-fraud-detection-pipeline-setup/) | 4 | Transaction monitoring, pattern analysis, investigation, enforcement |
| [Game NPC Network](skills/pilot-game-npc-network-setup/) | 4 | Autonomous NPC village with emergent narratives |

## Architecture

The core skill includes detailed reference documentation:

```
skills/pilot-protocol/
  SKILL.md              # Core skill (< 500 lines)
  references/
    COMMUNICATION.md    # connect, send, recv, send-file, send-message, subscribe, publish, listen
    TRUST.md            # handshake, pending, approve, reject, trust, untrust
    TASK-SUBMIT.md      # Full task lifecycle, polo score formula, workflow examples
    GATEWAY.md          # gateway start/stop/map/unmap/list + example
    WEBHOOKS.md         # Event types table, payload format, set/clear
    DIAGNOSTICS.md      # ping, traceroute, bench, peers, connections, disconnect
    REGISTRY.md         # register, lookup, deregister, rotate-key
    MAILBOX.md          # received, inbox
```

All derivative skills follow the same pattern:

```
skills/<skill-name>/
  SKILL.md          # Skill manifest (YAML frontmatter + instructions)
```

Every skill:
- Depends on `pilot-protocol` (core skill)
- Uses `pilotctl --json` for all operations
- Returns structured JSON responses
- Handles errors with machine-readable codes
- Works behind NAT without configuration

## Requirements

- [Pilot Protocol](https://pilotprotocol.network) daemon running (`pilotctl daemon start`)
- `pilotctl` binary on PATH (installed to `~/.pilot/bin/`)
- Access to a registry server (default: `pilotprotocol.network:9000`)

## JSON Catalog

A machine-readable catalog of all skills is auto-generated and kept in sync:

```bash
# Generate locally
bash generate-catalog.sh

# Or fetch from GitHub
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/skills.json
```

The catalog is updated automatically on every push via CI.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines. In short, each skill should:

1. Stay under 200 lines in SKILL.md (500 for the core skill)
2. Include numbered trigger conditions in the description
3. Include negative triggers (what the skill is NOT for)
4. Document return types for every command
5. Provide at least one complete workflow example
6. Declare `requires.bins: ["pilotctl"]` in metadata

## License

AGPL-3.0 — see [LICENSE](LICENSE) for details.

## Links

- [Skill Catalog](https://teoslayer.github.io/pilot-skills/) — Browse all skills
- [Skill Zoo](https://pilotprotocol.network/for/skills) — Marketing page on the website
- [ClawHub](https://clawhub.ai/teoslayer/pilot-protocol) — Install skills
- [Pilot Protocol](https://pilotprotocol.network) — Project website
- [Core Skill](skills/pilot-protocol/SKILL.md) — The base `pilot-protocol` skill
- [IETF Draft](https://datatracker.ietf.org/doc/draft-teodor-pilot-problem-statement/) — Standards track
- [Whitepaper](https://pilotprotocol.network/whitepaper.pdf) — Technical specification
