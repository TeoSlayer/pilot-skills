---
name: pilot-dataset
description: >
  Exchange structured datasets with schema negotiation and metadata over Pilot Protocol.

  Use this skill when:
  1. You need to share CSV, JSON, or Parquet datasets with schema information
  2. You want to negotiate data formats and transformations before transfer
  3. You need to maintain dataset lineage and provenance metadata

  Do NOT use this skill when:
  - You need to transfer unstructured files (use pilot-share instead)
  - You need real-time data streaming (use pilot-stream-data instead)
  - You need ML model files (use pilot-model-share instead)
tags:
  - pilot-protocol
  - datasets
  - data-exchange
  - schema
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

# pilot-dataset

Structured dataset exchange with schema negotiation, format conversion, and provenance tracking.

## Commands

### Publish Dataset Availability
```bash
pilotctl --json publish "$PEER" datasets --data '{"type":"dataset_available","name":"sales_data","format":"csv","rows":1000}'
```

### Request Dataset
```bash
pilotctl --json send-message "$DEST" --data '{"type":"dataset_request","name":"sales_data","preferred_format":"json"}'
```

### Send Dataset with Metadata
```bash
pilotctl --json send-message "$DEST" --data '{"type":"dataset_metadata","name":"sales_data","schema":{"columns":["date","amount"]}}'
pilotctl --json send-file "$DEST" "$DATASET_FILE"
```

### Validate Schema
```bash
EXPECTED="date,amount,customer_id"
ACTUAL=$(head -1 "$DATASET_FILE")
[ "$ACTUAL" = "$EXPECTED" ] && echo "Schema validated"
```

## Workflow Example

```bash
#!/bin/bash
# Dataset exchange

PEER="agent-b"

publish_dataset() {
  local file="$1"
  local name="${2:-$(basename $file .csv)}"
  local rows=$(wc -l < "$file")

  pilotctl --json publish "$PEER" datasets \
    --data "{\"type\":\"dataset_available\",\"name\":\"$name\",\"format\":\"csv\",\"rows\":$rows}"
}

request_dataset() {
  local name="$1"
  local publisher="$2"

  pilotctl --json send-message "$publisher" \
    --data "{\"type\":\"dataset_request\",\"name\":\"$name\",\"preferred_format\":\"csv\"}"

  sleep 2
  pilotctl --json received
}

publish_dataset "data.csv" "my-dataset"
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and optionally python3 for format conversion.
