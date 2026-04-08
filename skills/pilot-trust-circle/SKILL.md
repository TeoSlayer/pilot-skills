---
name: pilot-trust-circle
description: >
  Named trust groups with automatic mutual handshakes for Pilot Protocol agents.

  Use this skill when:
  1. You need to create groups of mutually trusting agents (teams, projects)
  2. You want to bootstrap trust for new agents joining a group
  3. You need to manage multiple distinct trust circles simultaneously

  Do NOT use this skill when:
  - You need hierarchical trust (use manual trust approval instead)
  - You're managing a single flat trust list (use pilot-auto-trust)
  - You need fine-grained per-connection trust policies
tags:
  - pilot-protocol
  - trust-security
  - collaboration
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

# Pilot Trust Circle

Manage named trust groups where all members automatically trust each other.

## Commands

### Create trust circle
```bash
mkdir -p ~/.pilot/circles
cat > ~/.pilot/circles/team-alpha.json <<EOF
{
  "name": "team-alpha",
  "description": "Production agents for Team Alpha",
  "members": ["agent1.pilot", "agent2.pilot", "agent3.pilot"]
}
EOF
```

### Add member to circle
```bash
CIRCLE="team-alpha"
NEW_MEMBER="agent4.pilot"

jq --arg member "$NEW_MEMBER" '.members += [$member]' \
  ~/.pilot/circles/$CIRCLE.json > /tmp/circle.json && \
  mv /tmp/circle.json ~/.pilot/circles/$CIRCLE.json

pilotctl --json handshake "$NEW_MEMBER" "Member of $CIRCLE"
NODE_ID=$(pilotctl --json find "$NEW_MEMBER" | jq -r '.[0].node_id')
pilotctl --json approve "$NODE_ID"
```

### Bootstrap circle membership
```bash
CIRCLE="team-alpha"

cat ~/.pilot/circles/$CIRCLE.json | jq -r '.members[]' | \
while read -r MEMBER; do
  pilotctl --json handshake "$MEMBER" "Trust circle: $CIRCLE" || true
done

pilotctl --json pending | jq -r '.[] | .hostname' | \
while read -r HOSTNAME; do
  if cat ~/.pilot/circles/$CIRCLE.json | jq -e --arg h "$HOSTNAME" '.members[] | select(. == $h)' >/dev/null; then
    NODE_ID=$(pilotctl --json pending | jq -r --arg h "$HOSTNAME" '.[] | select(.hostname == $h) | .node_id')
    pilotctl --json approve "$NODE_ID"
  fi
done
```

## Workflow Example

Create and bootstrap a new trust circle:

```bash
#!/bin/bash
CIRCLE="project-x"
MEMBERS=("alice.pilot" "bob.pilot" "charlie.pilot")

mkdir -p ~/.pilot/circles

cat > ~/.pilot/circles/$CIRCLE.json <<EOF
{
  "name": "$CIRCLE",
  "description": "Project X development team",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "members": $(printf '%s\n' "${MEMBERS[@]}" | jq -R . | jq -s .)
}
EOF

for MEMBER in "${MEMBERS[@]}"; do
  pilotctl --json handshake "$MEMBER" "Trust circle: $CIRCLE" || true
  sleep 1
done
```

## Dependencies

Requires pilot-protocol skill, pilotctl, and jq.
