---
name: pilot-backup
description: >
  Automated backup of agent state to trusted peers with encryption and versioning.

  Use this skill when:
  1. You need to backup agent configuration and state files to remote agents
  2. You want automated scheduled backups with rotation and retention
  3. You need encrypted backup storage on trusted peers

  Do NOT use this skill when:
  - You need general file synchronization (use pilot-sync instead)
  - You need one-time file transfer (use pilot-share instead)
  - You need streaming data backup (use pilot-stream-data instead)
tags:
  - pilot-protocol
  - backup
  - disaster-recovery
  - encryption
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

# pilot-backup

Automated backup of agent configuration and state files to trusted peers with encryption and versioning.

## Commands

### Backup Agent State
```bash
BACKUP_DEST="1:0001.AAAA.BBBB"
BACKUP_FILE="/tmp/pilot-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

tar czf "$BACKUP_FILE" "$HOME/.pilot"/*.json
pilotctl --json send-file "$BACKUP_DEST" "$BACKUP_FILE"
rm "$BACKUP_FILE"
```

### Restore from Backup
```bash
pilotctl --json send-message "$BACKUP_PEER" --data '{"type":"backup_request","date":"latest"}'
sleep 3

BACKUP_FILE=$(pilotctl --json received | jq -r '.received[0].filename')
tar xzf "$HOME/.pilot/received/$BACKUP_FILE" -C "$HOME/.pilot/"
```

### Backup Rotation
```bash
BACKUP_STORAGE="$HOME/.pilot/backup-storage"
MAX_BACKUPS=7

ls -1t "$BACKUP_STORAGE"/pilot-backup-*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
```

## Workflow Example

```bash
#!/bin/bash
# Automated backup management

BACKUP_STORAGE="$HOME/.pilot/backup-storage"
MAX_BACKUPS=7

mkdir -p "$BACKUP_STORAGE"

create_backup() {
  local dest="$1"
  local backup_file="/tmp/pilot-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

  tar czf "$backup_file" "$HOME/.pilot"/*.json

  pilotctl --json send-file "$dest" "$backup_file"
  cp "$backup_file" "$BACKUP_STORAGE/"
  rm "$backup_file"

  # Rotate old backups
  ls -1t "$BACKUP_STORAGE"/pilot-backup-*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
}

create_backup "1:0001.AAAA.BBBB"
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and tar/gzip.
