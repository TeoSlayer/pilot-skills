---
name: pilot-watchdog
description: >
  Security monitoring for suspicious network patterns in Pilot Protocol networks.

  Use this skill when:
  1. You need real-time detection of suspicious connection patterns
  2. You want automated alerts for security anomalies
  3. You need to monitor trust relationship changes continuously

  Do NOT use this skill when:
  - You only need audit logs (use pilot-audit-log)
  - You're doing one-time security checks (use pilot-verify)
tags:
  - pilot-protocol
  - trust-security
  - monitoring
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

# Pilot Watchdog

Real-time security monitoring for Pilot Protocol with anomaly detection, automated alerting, and threat response.

## Commands

### Initialize Watchdog

```bash
mkdir -p ~/.pilot/watchdog/{alerts,state}
cat > ~/.pilot/watchdog/config.json <<EOF
{
  "enabled": true,
  "check_interval_seconds": 30,
  "rules": {
    "connection_rate_limit": 10,
    "failed_handshake_threshold": 3,
    "queue_drop_threshold": 1
  }
}
EOF
```

### Monitor Connection Rate

```bash
# Detect abnormal connection rate
CURRENT=$(pilotctl --json connections 2>/dev/null | jq -r '.[].remote_hostname' | sort | uniq -c)

echo "$CURRENT" | while read -r COUNT AGENT; do
  if [ "$COUNT" -gt 10 ]; then
    echo "ALERT: $AGENT has $COUNT connections"
  fi
done
```

### Monitor Queue-Drop Counter

The daemon's `health` payload exposes `queue_drops` — when this is non-zero, the accept queue is overflowing (CPU saturation, fd limit too low, or DoS). Detect a regression by snapshotting and diffing.

```bash
STATE_FILE=~/.pilot/watchdog/state/queue_drops.txt

CURRENT=$(pilotctl --json health | jq -r '.queue_drops // 0')
PREVIOUS=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

if [ "$CURRENT" -gt "$PREVIOUS" ]; then
  DELTA=$((CURRENT - PREVIOUS))
  echo "ALERT: queue_drops increased by $DELTA since last check (now $CURRENT)"
fi

echo "$CURRENT" > "$STATE_FILE"
```

### Set Webhook for Events

```bash
# Configure daemon webhook
pilotctl --json set-webhook "http://localhost:8080/watchdog"
```

## Workflow Example

Continuous security monitoring with automated responses:

```bash
#!/bin/bash
WATCHDOG_DIR=~/.pilot/watchdog
INTERVAL=30

mkdir -p "$WATCHDOG_DIR"/{alerts,state}

# Alert function
alert() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$1] $2" | tee -a "$WATCHDOG_DIR/alerts/alerts.log"
}

# Monitor loop
while true; do
  # Check connection rate
  pilotctl --json connections | jq -r '.[].remote_hostname' | sort | uniq -c | \
    awk '$1 > 10 {print $2}' | while read agent; do
      alert "CONNECTION_RATE" "$agent exceeded connection limit"
    done

  # Check failed handshakes
  PENDING=$(pilotctl --json pending | jq length)
  if [ "$PENDING" -gt 5 ]; then
    alert "HANDSHAKE" "High number of pending handshakes: $PENDING"
  fi

  sleep $INTERVAL
done
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `jq`, and running daemon.
