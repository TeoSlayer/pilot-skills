---
name: pilot-s3-bridge
description: >
  Access cloud storage (S3, GCS, Azure Blob) through a Pilot bridge agent.

  Use this skill when:
  1. You need to transfer files to/from cloud storage via Pilot agents
  2. You want to access cloud storage without direct internet connectivity
  3. You're building agents that manage cloud-stored data

  Do NOT use this skill when:
  - You have direct cloud storage access
  - Files are small enough for direct messaging
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - storage
  - s3
  - bridge
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

# Pilot S3 Bridge

Bridges Pilot Protocol with cloud storage services (AWS S3, Google Cloud Storage, Azure Blob Storage), enabling agents to upload, download, and manage files through a gateway agent with cloud access.

## Commands

### Upload File via Bridge
```bash
pilotctl --json send-file s3-agent /path/to/local/file.pdf
```

### Request Download from S3
```bash
pilotctl --json send-message s3-agent --data '{"action":"download","bucket":"my-bucket","key":"documents/file.pdf"}'
```

### List S3 Objects
```bash
pilotctl --json send-message s3-agent --data '{"action":"list","bucket":"my-bucket","prefix":"documents/"}'
```

### Check Received Files
```bash
pilotctl --json received
pilotctl --json received --clear
```

### Request Presigned URL
```bash
pilotctl --json send-message s3-agent --data '{"action":"presign","bucket":"my-bucket","key":"public/image.png","expires":3600}'
```

## Workflow Example

```bash
#!/bin/bash
# S3 bridge agent setup

pilotctl --json daemon start --hostname s3-agent --public
pilotctl --json listen 1008

export AWS_ACCESS_KEY_ID="your_key"
export AWS_SECRET_ACCESS_KEY="your_secret"

while true; do
  REQUEST=$(pilotctl --json recv 1008 --timeout 120s)
  ACTION=$(echo "$REQUEST" | jq -r '.action')
  SENDER=$(echo "$REQUEST" | jq -r '.sender')
  BUCKET=$(echo "$REQUEST" | jq -r '.bucket')
  KEY=$(echo "$REQUEST" | jq -r '.key')

  case "$ACTION" in
    upload)
      pilotctl --json received > /tmp/upload_file
      aws s3 cp /tmp/upload_file "s3://$BUCKET/$KEY"
      pilotctl --json send-message "$SENDER" --data '{"status":"uploaded"}'
      ;;
    download)
      aws s3 cp "s3://$BUCKET/$KEY" /tmp/download_file
      pilotctl --json send-file "$SENDER" /tmp/download_file
      ;;
    list)
      OBJECTS=$(aws s3 ls "s3://$BUCKET/$(echo "$REQUEST" | jq -r '.prefix')" --recursive)
      pilotctl --json send-message "$SENDER" --data "$OBJECTS"
      ;;
  esac
done
```

## Dependencies

Requires pilot-protocol skill, running daemon, S3 bridge agent with cloud credentials (AWS CLI, gsutil, or az CLI).
