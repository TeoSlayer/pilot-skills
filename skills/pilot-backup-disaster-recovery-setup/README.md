# Backup & Disaster Recovery Setup

Automated backup infrastructure across multiple sites. A scheduler triggers periodic backups, the primary backup agent compresses and archives data, a secondary site syncs copies for disaster recovery, and a tester periodically restores and verifies backup integrity.

**Difficulty:** Intermediate | **Agents:** 4

## Roles

### backup-sched (Backup Scheduler)
Orchestrates the backup lifecycle on a cron schedule. Triggers backups, monitors completion, and sends reports to Slack.

**Skills:** pilot-cron, pilot-task-chain, pilot-audit-log, pilot-slack-bridge

### backup-primary (Primary Backup)
Creates backups of databases and file systems. Compresses and archives them locally, then shares with the offsite secondary.

**Skills:** pilot-backup, pilot-archive, pilot-compress, pilot-share

### backup-secondary (Offsite Replica)
Receives backup archives from the primary site and syncs them to offsite storage. Verifies integrity checksums and reports health.

**Skills:** pilot-sync, pilot-verify, pilot-health, pilot-share

### restore-tester (Restore Tester)
Periodically pulls backups from the secondary, attempts a full restore in an isolated environment, and verifies data integrity. Alerts on failures.

**Skills:** pilot-backup, pilot-verify, pilot-health, pilot-alert

## Data Flow

```
backup-sched    --> backup-primary   : Triggers scheduled backup jobs (port 1002)
backup-primary  --> backup-secondary : Transfers compressed backup archives (port 1001)
backup-secondary --> restore-tester  : Provides backups for restore testing (port 1001)
restore-tester  --> backup-sched     : Reports restore test results (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On scheduler node
clawhub install pilot-cron pilot-task-chain pilot-audit-log pilot-slack-bridge
pilotctl set-hostname <your-prefix>-backup-sched

# On primary backup server
clawhub install pilot-backup pilot-archive pilot-compress pilot-share
pilotctl set-hostname <your-prefix>-backup-primary

# On offsite secondary (different region/datacenter)
clawhub install pilot-sync pilot-verify pilot-health pilot-share
pilotctl set-hostname <your-prefix>-backup-secondary

# On restore test server
clawhub install pilot-backup pilot-verify pilot-health pilot-alert
pilotctl set-hostname <your-prefix>-restore-tester
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# scheduler <-> primary
# On backup-sched:
pilotctl handshake <your-prefix>-backup-primary "backup dr"
# On backup-primary:
pilotctl handshake <your-prefix>-backup-sched "backup dr"

# primary <-> secondary
# On backup-primary:
pilotctl handshake <your-prefix>-backup-secondary "backup dr"
# On backup-secondary:
pilotctl handshake <your-prefix>-backup-primary "backup dr"

# secondary <-> tester
# On backup-secondary:
pilotctl handshake <your-prefix>-restore-tester "backup dr"
# On restore-tester:
pilotctl handshake <your-prefix>-backup-secondary "backup dr"

# tester <-> scheduler
# On restore-tester:
pilotctl handshake <your-prefix>-backup-sched "backup dr"
# On backup-sched:
pilotctl handshake <your-prefix>-restore-tester "backup dr"

# scheduler <-> secondary
# On backup-sched:
pilotctl handshake <your-prefix>-backup-secondary "backup dr"
# On backup-secondary:
pilotctl handshake <your-prefix>-backup-sched "backup dr"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-backup-sched — trigger a scheduled backup:
pilotctl publish <your-prefix>-backup-primary backup-start '{"job_id":"BK-0315","type":"full","targets":["postgres","redis"]}'

# On <your-prefix>-backup-primary — create and ship backup:
pilotctl send-file <your-prefix>-backup-secondary ./backups/BK-0315-postgres.tar.gz
pilotctl send-file <your-prefix>-backup-secondary ./backups/BK-0315-redis.rdb
pilotctl publish <your-prefix>-backup-secondary sync-backup '{"job_id":"BK-0315","files":2,"size_mb":1240,"checksum":"sha256:d4e5f6"}'

# On <your-prefix>-backup-secondary — confirm sync:
pilotctl publish <your-prefix>-backup-sched sync-confirmed '{"job_id":"BK-0315","verified":true,"checksum_match":true}'

# On <your-prefix>-restore-tester — test restore and report:
pilotctl publish <your-prefix>-backup-sched restore-result '{"job_id":"BK-0315","restore":"success","tables_verified":42,"rows_checked":100000}'
```
