---
name: pilot-cron
description: >
  Scheduled recurring task submission.

  Use this skill when:
  1. You need periodic task execution on a fixed schedule
  2. You want automated recurring tasks without manual intervention
  3. You need time-based triggers for network operations

  Do NOT use this skill when:
  - Tasks should trigger on events, not time (use pilot-workflow)
  - You only need to run a task once
  - The schedule is irregular and can't be expressed as a cron pattern
tags:
  - pilot-protocol
  - task-workflow
  - scheduling
  - automation
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

# pilot-cron

Scheduled recurring task submission using cron-style scheduling. Enables automated periodic task execution across the Pilot network.

## Commands

**Add cron job:**
```bash
crontab -l | { cat; echo "0 * * * * /path/to/submit-task.sh"; } | crontab -  # Every hour
crontab -l | { cat; echo "0 2 * * * /path/to/daily-backup.sh"; } | crontab -  # Daily at 2 AM
```

**Systemd timer (more reliable):**
```bash
cat > ~/.config/systemd/user/pilot-task.timer <<EOF
[Timer]
OnCalendar=hourly
Persistent=true
EOF

systemctl --user enable pilot-task.timer
systemctl --user start pilot-task.timer
```

**Simple sleep loop:**
```bash
while true; do
  /path/to/submit-task.sh
  sleep 3600  # 1 hour
done
```

**List scheduled tasks:**
```bash
crontab -l
systemctl --user list-timers
```

## Workflow Example

```bash
#!/bin/bash
# Create and install cron jobs

SCRIPT_DIR="$HOME/.pilot/cron-jobs"
mkdir -p "$SCRIPT_DIR"

# Health check script - every 5 minutes
cat > "$SCRIPT_DIR/health-check.sh" <<'EOF'
#!/bin/bash
AGENT=$(pilotctl --json peers --search "monitor" | jq -r '.[0].address')
pilotctl --json task submit "$AGENT" --task "Perform health check and report status"
EOF
chmod +x "$SCRIPT_DIR/health-check.sh"

# Install cron jobs
crontab -l 2>/dev/null | grep -v 'pilot-cron' > /tmp/crontab.tmp || true
cat >> /tmp/crontab.tmp <<EOF
# pilot-cron: Health check every 5 minutes
*/5 * * * * $SCRIPT_DIR/health-check.sh >> $HOME/.pilot/logs/health-check.log 2>&1
EOF
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp

echo "Cron jobs installed"
```

## Common Cron Patterns

```bash
* * * * *       # Every minute
*/5 * * * *     # Every 5 minutes
0 * * * *       # Every hour
0 2 * * *       # Daily at 2 AM
0 9 * * 1       # Monday at 9 AM
0 0 1 * *       # First day of month
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, `jq`, and `cron` or `systemd` timer support.
