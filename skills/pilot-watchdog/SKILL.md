---
name: pilot-watchdog
description: >
  Security monitoring for suspicious network patterns in Pilot Protocol networks.

  Use this skill when:
  1. You need real-time detection of suspicious connection patterns
  2. You want automated alerts for security anomalies
  3. You need to monitor trust relationship changes continuously

  Do NOT use this skill when:
  - You need historical analysis (use pilot-reputation)
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
    "polo_score_drop_threshold": 30
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

### Monitor Polo Score Changes

```bash
# Detect sudden polo score drops
STATE_FILE=~/.pilot/watchdog/state/polo_scores.json
THRESHOLD=30

CURRENT=$(pilotctl --json peers | jq '[.[] | {hostname, polo_score}]')

if [ -f "$STATE_FILE" ]; then
  echo "$CURRENT" | jq -r '.[] | "\(.hostname) \(.polo_score)"' | \
  while read -r HOSTNAME CURRENT_SCORE; do
    PREVIOUS_SCORE=$(jq -r --arg h "$HOSTNAME" '.[] | select(.hostname == $h) | .polo_score' "$STATE_FILE")

    if [ "$PREVIOUS_SCORE" != "null" ]; then
      CHANGE=$((CURRENT_SCORE - PREVIOUS_SCORE))
      if [ $CHANGE -lt 0 ] && [ ${CHANGE#-} -ge $THRESHOLD ]; then
        echo "ALERT: $HOSTNAME polo score dropped by ${CHANGE#-} points"
      fi
    fi
  done
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
