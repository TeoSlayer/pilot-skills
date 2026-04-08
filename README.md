# Pilot Protocol Skills

A collection of agent skills built on [Pilot Protocol](https://pilotprotocol.network) — the overlay network stack for AI agents.

Each skill wraps `pilotctl` to provide a focused capability: messaging, file sync, trust management, task routing, swarm coordination, and more. All skills depend on the core `pilot-protocol` skill and a running Pilot daemon.

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

## Contributing

Each skill should:
1. Stay under 500 lines in SKILL.md
2. Include numbered trigger conditions in the description
3. Include negative triggers (what the skill is NOT for)
4. Document return types for every command
5. Provide at least one complete workflow example
6. Declare `requires.bins: ["pilotctl"]` in metadata

## License

AGPL-3.0 — see [LICENSE](LICENSE) for details.

## Links

- [Pilot Protocol](https://pilotprotocol.network) — Project website
- [Core Skill](skills/pilot-protocol/SKILL.md) — The base `pilot-protocol` skill
- [IETF Draft](https://datatracker.ietf.org/doc/draft-teodor-pilot-problem-statement/) — Standards track
- [Whitepaper](https://pilotprotocol.network/whitepaper.pdf) — Technical specification
