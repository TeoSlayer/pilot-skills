---
name: pilot-announce-capabilities
description: >
  Broadcast structured capability manifests to the network.

  Use this skill when:
  1. Advertising services, resources, or APIs your agent provides
  2. Publishing structured capability metadata (specs, pricing, SLAs)
  3. Making your agent discoverable by specific capabilities

  Do NOT use this skill when:
  - You only need simple tags (use set-tags in pilot-protocol instead)
  - You need to discover other agents (use pilot-discover instead)
  - You need to establish trust (use pilot-trust instead)
tags:
  - pilot-protocol
  - capabilities
  - discovery
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# pilot-announce-capabilities

Broadcast structured capability manifests to the Pilot Protocol network. Advertise services, resources, APIs, pricing, and SLAs in a machine-readable format for rich service discovery.

## Commands

### Set capability tags

```bash
pilotctl --json set-tags tag1 tag2 tag3
```

Sets capability tags for your agent.

### Publish capability manifest

```bash
pilotctl --json publish <target> "capabilities" --data "$(cat manifest.json)"
```

Publishes a structured JSON manifest to a target topic.

### Subscribe to announcements

```bash
pilotctl --json subscribe <target> "capabilities"
```

Listens for capability announcements from a target.

### List peer capabilities

```bash
pilotctl --json peers --search "tag1 tag2"
```

Finds agents by capability tags.

## Capability Manifest Schema

```json
{
  "agent": {
    "node_id": "0x12345678",
    "hostname": "ai-inference-01",
    "version": "1.4.1"
  },
  "capabilities": [
    {
      "type": "ai-inference",
      "model": "llama-3-70b",
      "context_length": 8192,
      "tokens_per_second": 120,
      "pricing": {
        "input_per_1m_tokens": 0.50,
        "output_per_1m_tokens": 1.50,
        "currency": "USD"
      },
      "sla": {
        "uptime_pct": 99.5,
        "max_latency_ms": 500
      }
    }
  ],
  "endpoints": {
    "api": "pilot://ai-inference-01:80/v1/chat/completions"
  },
  "metadata": {
    "location": "us-east-1",
    "gpu": "A100-80GB",
    "updated_at": "2026-04-08T10:30:00Z"
  }
}
```

## Workflow Example

Advertise AI inference capability:

```bash
# Set basic capability tags
pilotctl --json set-tags ai inference llm

# Create detailed manifest
cat > capability_manifest.json <<EOF
{
  "capabilities": [{
    "type": "ai-inference",
    "model": "llama-3-70b",
    "tokens_per_second": 120,
    "pricing": {"input_per_1m_tokens": 0.50, "currency": "USD"},
    "sla": {"uptime_pct": 99.5, "max_latency_ms": 500}
  }],
  "metadata": {"gpu": "A100 80GB", "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
}
EOF

# Publish manifest (assuming a registry or broadcast target)
REGISTRY=$(pilotctl --json find registry | jq -r '.address')
pilotctl --json publish "$REGISTRY" "capabilities" --data "$(cat capability_manifest.json)"

# Verify discoverability
pilotctl --json peers --search "ai llm"
```

## Capability Types

- **ai-inference**: Model, context length, tokens/sec, pricing
- **compute**: CPU cores, RAM, GPU, pricing per hour
- **storage**: Capacity, IOPS, protocols, pricing per GB
- **api-gateway**: Protocols, rate limits, SSL, pricing per request

## Dependencies

Requires pilot-protocol skill with running daemon. For event stream publishing, registry must support port 1002.
