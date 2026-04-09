---
name: pilot-backup-disaster-recovery-setup
description: >
  Deploy a backup and disaster recovery system with 4 agents.

  Use this skill when:
  1. User wants to set up automated backup infrastructure
  2. User is configuring a scheduler, backup, offsite replica, or restore tester agent
  3. User asks about disaster recovery, offsite sync, or backup verification

  Do NOT use this skill when:
  - User wants a single backup operation (use pilot-backup instead)
  - User wants to verify a single file (use pilot-verify instead)
tags:
  - pilot-protocol
  - setup
  - backup
  - disaster-recovery
license: AGPL-3.0
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - clawhub
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Backup & Disaster Recovery Setup

Deploy 4 agents: scheduler, primary backup, offsite secondary, and restore tester.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| scheduler | `<prefix>-backup-sched` | pilot-cron, pilot-task-chain, pilot-audit-log, pilot-slack-bridge | Orchestrates backup lifecycle |
| primary | `<prefix>-backup-primary` | pilot-backup, pilot-archive, pilot-compress, pilot-share | Creates and ships backups |
| secondary | `<prefix>-backup-secondary` | pilot-sync, pilot-verify, pilot-health, pilot-share | Offsite replica, verifies integrity |
| tester | `<prefix>-restore-tester` | pilot-backup, pilot-verify, pilot-health, pilot-alert | Tests restores, alerts on failures |

## Setup Procedure

**Step 1:** Ask the user which role and prefix.

**Step 2:** Install skills:
```bash
# scheduler:
clawhub install pilot-cron pilot-task-chain pilot-audit-log pilot-slack-bridge
# primary:
clawhub install pilot-backup pilot-archive pilot-compress pilot-share
# secondary:
clawhub install pilot-sync pilot-verify pilot-health pilot-share
# tester:
clawhub install pilot-backup pilot-verify pilot-health pilot-alert
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/backup-disaster-recovery.json`.

**Step 4:** Handshake along the chain: scheduler↔primary↔secondary↔tester↔scheduler.

## Manifest Templates Per Role

### scheduler
```json
{
  "setup": "backup-disaster-recovery", "role": "scheduler", "role_name": "Backup Scheduler",
  "hostname": "<prefix>-backup-sched",
  "skills": {
    "pilot-cron": "Schedule periodic backup jobs (hourly, daily, weekly).",
    "pilot-task-chain": "Orchestrate backup → sync → verify → report.",
    "pilot-audit-log": "Log all backup lifecycle events.",
    "pilot-slack-bridge": "Send backup reports and failure alerts to Slack."
  },
  "data_flows": [
    { "direction": "send", "peer": "<prefix>-backup-primary", "port": 1002, "topic": "backup-start", "description": "Trigger backup jobs" },
    { "direction": "receive", "peer": "<prefix>-restore-tester", "port": 1002, "topic": "restore-result", "description": "Restore test results" }
  ],
  "handshakes_needed": ["<prefix>-backup-primary", "<prefix>-backup-secondary", "<prefix>-restore-tester"]
}
```

### primary
```json
{
  "setup": "backup-disaster-recovery", "role": "primary", "role_name": "Primary Backup",
  "hostname": "<prefix>-backup-primary",
  "skills": {
    "pilot-backup": "Create database and filesystem backups.",
    "pilot-archive": "Archive backups with metadata and retention.",
    "pilot-compress": "Compress archives before transfer.",
    "pilot-share": "Ship compressed archives to secondary."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-backup-sched", "port": 1002, "topic": "backup-start", "description": "Backup triggers" },
    { "direction": "send", "peer": "<prefix>-backup-secondary", "port": 1001, "topic": "sync-backup", "description": "Compressed archives" }
  ],
  "handshakes_needed": ["<prefix>-backup-sched", "<prefix>-backup-secondary"]
}
```

### secondary
```json
{
  "setup": "backup-disaster-recovery", "role": "secondary", "role_name": "Offsite Replica",
  "hostname": "<prefix>-backup-secondary",
  "skills": {
    "pilot-sync": "Receive and sync backup archives from primary.",
    "pilot-verify": "Verify integrity checksums on received backups.",
    "pilot-health": "Report offsite storage health and capacity.",
    "pilot-share": "Provide backups to restore tester on demand."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-backup-primary", "port": 1001, "topic": "sync-backup", "description": "Compressed archives" },
    { "direction": "send", "peer": "<prefix>-restore-tester", "port": 1001, "topic": "restore-data", "description": "Backups for testing" },
    { "direction": "send", "peer": "<prefix>-backup-sched", "port": 1002, "topic": "sync-confirmed", "description": "Sync confirmation" }
  ],
  "handshakes_needed": ["<prefix>-backup-primary", "<prefix>-backup-sched", "<prefix>-restore-tester"]
}
```

### tester
```json
{
  "setup": "backup-disaster-recovery", "role": "tester", "role_name": "Restore Tester",
  "hostname": "<prefix>-restore-tester",
  "skills": {
    "pilot-backup": "Perform test restores in isolated environment.",
    "pilot-verify": "Verify restored data integrity (row counts, checksums).",
    "pilot-health": "Monitor restore test environment health.",
    "pilot-alert": "Alert on restore failures or data corruption."
  },
  "data_flows": [
    { "direction": "receive", "peer": "<prefix>-backup-secondary", "port": 1001, "topic": "restore-data", "description": "Backups to test" },
    { "direction": "send", "peer": "<prefix>-backup-sched", "port": 1002, "topic": "restore-result", "description": "Test results" }
  ],
  "handshakes_needed": ["<prefix>-backup-secondary", "<prefix>-backup-sched"]
}
```

## Data Flows

- `scheduler → primary` : backup triggers (port 1002)
- `primary → secondary` : compressed archives (port 1001)
- `secondary → tester` : backups for testing (port 1001)
- `tester → scheduler` : restore test results (port 1002)

## Workflow Example

```bash
# On scheduler:
pilotctl --json publish <prefix>-backup-primary backup-start '{"job_id":"BK-315","type":"full","targets":["postgres","redis"]}'
# On primary:
pilotctl --json send-file <prefix>-backup-secondary ./backups/BK-315-postgres.tar.gz
pilotctl --json publish <prefix>-backup-secondary sync-backup '{"job_id":"BK-315","size_mb":1240}'
# On tester:
pilotctl --json publish <prefix>-backup-sched restore-result '{"job_id":"BK-315","restore":"success","tables_verified":42}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
