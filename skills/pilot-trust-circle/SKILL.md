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
  version: "1.1"
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

A circle file pins each member's **node ID and public key**, and the bootstrap
approves a pending request only when both match a pinned member. Never match
on hostname: registry hostnames are first-come, so anyone can claim a
member's name that is not registered yet (or was released), send a handshake,
and pass a hostname check. Members stored as plain hostname strings (the old
format of this file) are never auto-approved — re-add each one with *Add
member to circle* to pin it.

## Commands

### Create trust circle
```bash
mkdir -p ~/.pilot/circles
cat > ~/.pilot/circles/team-alpha.json <<'EOF'
{
  "name": "team-alpha",
  "description": "Production agents for Team Alpha",
  "members": []
}
EOF
```

Then add each member with *Add member to circle*.

### Add member to circle

Pinning is trust on first use: it records the node ID and key the registry
holds for that hostname right now. Confirm the key with the member out of
band (they print theirs with `pilotctl --json info | jq -r '.data.public_key'`)
and set `EXPECTED_KEY`. A member that rotates its key must be re-added.

```bash
CIRCLE_FILE=~/.pilot/circles/team-alpha.json
NEW_MEMBER="agent4"
EXPECTED_KEY=""   # the member's public key, confirmed with them out of band

# Pin the member's node ID and public key from the registry
MEMBER=$(pilotctl --json lookup "$NEW_MEMBER" | jq -c '.data | {hostname, node_id, public_key}')
KEY=$(echo "$MEMBER" | jq -r '.public_key // empty')
if [ -z "$KEY" ] || { [ -n "$EXPECTED_KEY" ] && [ "$KEY" != "$EXPECTED_KEY" ]; }; then
  echo "Not adding $NEW_MEMBER: registry key '${KEY:-none}' is missing or not the expected key"
else
  jq --argjson m "$MEMBER" '.members = [.members[] | select(type != "object" or .node_id != $m.node_id)] + [$m]' \
    "$CIRCLE_FILE" > "$CIRCLE_FILE.tmp" && mv "$CIRCLE_FILE.tmp" "$CIRCLE_FILE"
  NODE_ID=$(echo "$MEMBER" | jq -r '.node_id')
  pilotctl --json handshake "$NODE_ID" "Member of team-alpha"
  # Only succeeds if they have already sent us a handshake request
  pilotctl --json approve "$NODE_ID" || true
fi
```

### Bootstrap circle membership
```bash
CIRCLE="team-alpha"
CIRCLE_FILE=~/.pilot/circles/$CIRCLE.json

# Request trust with every pinned member, by node ID (never by hostname)
jq -r '.members[] | objects | .node_id // empty' "$CIRCLE_FILE" | \
while read -r NODE_ID; do
  pilotctl --json handshake "$NODE_ID" "Trust circle: $CIRCLE" || true
done

# Approve a pending request only if its node ID AND public key match a pinned
# member; everything else stays pending for manual review
pilotctl --json pending | jq -c '.data.pending[] | {node_id, public_key}' | \
while read -r REQ; do
  if jq -e --argjson r "$REQ" \
      'any(.members[] | objects; .node_id == $r.node_id and (.public_key // "") != "" and .public_key == $r.public_key)' \
      "$CIRCLE_FILE" >/dev/null; then
    pilotctl --json approve "$(echo "$REQ" | jq -r '.node_id')"
  fi
done
```

## Workflow Example

Create and bootstrap a new trust circle:

```bash
#!/bin/bash
CIRCLE="project-x"
MEMBERS=("alice" "bob" "charlie")
CIRCLE_FILE=~/.pilot/circles/$CIRCLE.json

mkdir -p ~/.pilot/circles

# Pin every member that is registered now. A name that is not registered yet
# is left out: add it with "Add member to circle" once its owner registers it.
PINNED="[]"
for MEMBER in "${MEMBERS[@]}"; do
  if RECORD=$(pilotctl --json lookup "$MEMBER" 2>/dev/null) &&
     ENTRY=$(echo "$RECORD" | jq -ce '.data | select(.public_key) | {hostname, node_id, public_key}'); then
    PINNED=$(echo "$PINNED" | jq -c --argjson m "$ENTRY" '. + [$m]')
  else
    echo "Skipping $MEMBER: not registered"
  fi
done

jq -n --arg name "$CIRCLE" --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson members "$PINNED" \
  '{name: $name, description: "Project X development team", created: $created, members: $members}' \
  > "$CIRCLE_FILE"

# Request trust with each pinned member by node ID
jq -r '.members[].node_id' "$CIRCLE_FILE" | while read -r NODE_ID; do
  pilotctl --json handshake "$NODE_ID" "Trust circle: $CIRCLE" || true
  sleep 1
done

echo "Pinned members (confirm each key with its owner):"
jq -r '.members[] | "\(.hostname)  node \(.node_id)  key \(.public_key)"' "$CIRCLE_FILE"
```

## Dependencies

Requires pilot-protocol skill, pilotctl, and jq.
