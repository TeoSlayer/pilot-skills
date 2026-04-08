---
name: pilot-model-share
description: >
  Distribute ML model files with model card metadata and version tracking over Pilot Protocol.

  Use this skill when:
  1. You need to share PyTorch, ONNX, or SafeTensors model files between agents
  2. You want to distribute models with metadata (architecture, training info, metrics)
  3. You need model versioning and compatibility checking

  Do NOT use this skill when:
  - You need to transfer datasets (use pilot-dataset instead)
  - You need to transfer general files (use pilot-share instead)
  - You need real-time model inference results (use pilot-rpc instead)
tags:
  - pilot-protocol
  - machine-learning
  - model-sharing
  - ml-ops
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

# pilot-model-share

ML model distribution with model cards, metadata, and version tracking.

## Commands

### Publish Model Availability
```bash
pilotctl --json publish "$PEER" models --data '{"type":"model_available","name":"resnet50","version":"1.0.0","framework":"pytorch"}'
```

### Request Model
```bash
pilotctl --json send-message "$DEST" --data '{"type":"model_request","name":"resnet50","preferred_format":"onnx"}'
```

### Send Model with Metadata
```bash
pilotctl --json send-message "$DEST" --data '{"type":"model_metadata","name":"llama3_8b","file":{"checksum":"abc123"}}'
pilotctl --json send-file "$DEST" "$MODEL_FILE"
```

### Validate Checksum
```bash
EXPECTED_CHECKSUM=$(pilotctl --json inbox | jq -r '.messages[] | select(.type == "model_metadata") | .file.checksum' | head -1)
ACTUAL_CHECKSUM=$(md5sum "$RECEIVED_MODEL" | cut -d' ' -f1)
[ "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" ] && echo "Model verified"
```

## Workflow Example

```bash
#!/bin/bash
# Model distribution

PEER="agent-b"

share_model() {
  local model_file="$1"
  local model_name="${2:-$(basename $model_file .pth)}"

  pilotctl --json publish "$PEER" models --data "{\"type\":\"model_available\",\"name\":\"$model_name\"}"
}

share_model "model.pth" "my-model"
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and md5sum.
