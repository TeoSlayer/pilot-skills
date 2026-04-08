---
name: pilot-quarantine
description: >
  Isolate suspicious agents pending investigation in Pilot Protocol networks.

  Use this skill when:
  1. You detect compromised or suspicious agents that need isolation
  2. You want to temporarily suspend trust without permanent blocking
  3. You need to investigate agent behavior before making final trust decisions

  Do NOT use this skill when:
  - You need permanent blocking (use pilot-blocklist)
  - You're doing preventive blocking (use trust policies)
  - You need immediate disconnect (use pilotctl disconnect)
tags:
  - pilot-protocol
  - trust-security
  - incident-response
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

# Pilot Quarantine

Temporary isolation system for suspicious agents with investigation workflows and automated review.

## Commands

### Quarantine Agent
```bash
AGENT="suspicious.pilot"
QUARANTINE_ID=$(openssl rand -hex 6)
NODE_ID=$(pilotctl --json find "$AGENT" | jq -r '.node_id')

pilotctl --json untrust "$NODE_ID"
pilotctl --json connections | jq -r '.connections[] | select(.remote_hostname == "'"$AGENT"'") | .id' | \
  xargs -I {} pilotctl --json disconnect {}
```

### List Quarantined Agents
```bash
for QFILE in ~/.pilot/quarantine/active/*.json; do
  jq -r '"ID: \(.quarantine_id) Agent: \(.agent) Reason: \(.reason)"' "$QFILE"
done
```

### Release from Quarantine
```bash
QUARANTINE_ID="abc123"
QFILE=~/.pilot/quarantine/active/$QUARANTINE_ID.json
AGENT=$(jq -r '.agent' "$QFILE")

mv "$QFILE" ~/.pilot/quarantine/resolved/
pilotctl --json handshake "$AGENT" "Quarantine released"
```

### Enforce Quarantine
```bash
for QFILE in ~/.pilot/quarantine/active/*.json; do
  AGENT=$(jq -r '.agent' "$QFILE")
  NODE_ID=$(jq -r '.node_id' "$QFILE")

  pilotctl --json connections | jq -r '.connections[] | select(.remote_hostname == "'"$AGENT"'") | .id' | \
    xargs -I {} pilotctl --json disconnect {}
done
```

## Workflow Example

```bash
#!/bin/bash
# Quarantine management

mkdir -p ~/.pilot/quarantine/{active,resolved}

AGENT="malicious.pilot"
QUARANTINE_ID=$(openssl rand -hex 6)
NODE_ID=$(pilotctl --json find "$AGENT" | jq -r '.node_id')

pilotctl --json untrust "$NODE_ID"

cat > ~/.pilot/quarantine/active/$QUARANTINE_ID.json <<EOF
{
  "quarantine_id": "$QUARANTINE_ID",
  "agent": "$AGENT",
  "reason": "Port scanning detected",
  "quarantined_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "active"
}
EOF

echo "Quarantined: $AGENT (ID: $QUARANTINE_ID)"
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, openssl. Quarantine records stored in ~/.pilot/quarantine/.
