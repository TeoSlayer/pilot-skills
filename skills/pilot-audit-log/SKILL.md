---
name: pilot-audit-log
description: >
  Comprehensive audit trail of all Pilot Protocol activity for security and compliance.

  Use this skill when:
  1. You need detailed logs of all trust decisions and connections
  2. You require compliance audit trails for security reviews
  3. You want to investigate suspicious activity or incidents

  Do NOT use this skill when:
  - You need real-time alerting (use pilot-watchdog instead)
  - You only need basic daemon logs (use pilotctl info)
  - You're doing performance profiling (use dedicated profiling tools)
tags:
  - pilot-protocol
  - trust-security
  - audit
  - compliance
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

# Pilot Audit Log

Comprehensive audit logging for Pilot Protocol with structured event capture, retention policies, and compliance-ready output formats.

## Commands

**Initialize audit log:**
```bash
mkdir -p ~/.pilot/audit
cat > ~/.pilot/audit/config.json <<EOF
{
  "enabled": true,
  "log_file": "$HOME/.pilot/audit/events.jsonl",
  "retention_days": 90,
  "event_types": ["trust.handshake", "trust.approve", "connection.open"]
}
EOF
```

**Log trust events:**
```bash
log_audit() {
  local EVENT_TYPE=$1
  local DETAILS=$2
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $EVENT_TYPE $DETAILS" >> ~/.pilot/audit/events.jsonl
}

pilotctl --json handshake "$AGENT" "Audit test"
log_audit "trust.handshake" "{\"agent\": \"$AGENT\"}"
```

**Query audit log:**
```bash
grep "trust.approve" ~/.pilot/audit/events.jsonl
jq 'select(.event_type == "trust.approve")' ~/.pilot/audit/events.jsonl
```

**Generate audit report:**
```bash
cat > ~/.pilot/audit/report-$(date +%Y-%m-%d).json <<EOF
{
  "date": "$(date +%Y-%m-%d)",
  "total_events": $(wc -l < ~/.pilot/audit/events.jsonl),
  "handshakes": $(grep -c "trust.handshake" ~/.pilot/audit/events.jsonl || echo 0),
  "approvals": $(grep -c "trust.approve" ~/.pilot/audit/events.jsonl || echo 0)
}
EOF
```

## Workflow Example

```bash
#!/bin/bash
# Audit logging with automatic event capture

AUDIT_DIR=~/.pilot/audit
LOG_FILE=$AUDIT_DIR/events.jsonl
mkdir -p "$AUDIT_DIR"

audit_log() {
  local EVENT_TYPE=$1
  local AGENT=$2
  local ACTION=$3
  local RESULT=$4

  cat >> "$LOG_FILE" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","event_type":"$EVENT_TYPE","agent":"$AGENT","action":"$ACTION","result":"$RESULT"}
EOF
}

# Wrap trust commands with audit logging
audit_handshake() {
  local AGENT=$1
  audit_log "trust" "$AGENT" "handshake" "started"

  if pilotctl --json handshake "$AGENT" "Audit tracked"; then
    audit_log "trust" "$AGENT" "handshake" "success"
  else
    audit_log "trust" "$AGENT" "handshake" "failed"
  fi
}

audit_handshake "agent1.pilot"
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, and `jq` for JSON parsing.
