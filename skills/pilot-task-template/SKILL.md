---
name: pilot-task-template
description: >
  Reusable task templates with placeholder substitution.

  Use this skill when:
  1. You need to define common task patterns for reuse
  2. You want parameterized task definitions with variable substitution
  3. You need to standardize task formats across your organization

  Do NOT use this skill when:
  - Each task is unique and won't be reused
  - You don't need parameter substitution
  - Simple command-line arguments are sufficient
tags:
  - pilot-protocol
  - task-workflow
  - template
  - reusability
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

# pilot-task-template

Define reusable task templates with placeholder substitution. Enables standardized task patterns that can be instantiated with different parameters.

## Essential Commands

### Define template
```bash
cat > /tmp/ml-inference-template.txt <<'EOF'
Run ML inference using model {{MODEL}} with prompt: {{PROMPT}}, temperature {{TEMPERATURE}}
EOF
```

### Substitute variables
```bash
TEMPLATE=$(cat /tmp/ml-inference-template.txt)

TASK_DESC=$(echo "$TEMPLATE" | \
  sed "s/{{MODEL}}/$MODEL/g" | \
  sed "s/{{PROMPT}}/$PROMPT/g" | \
  sed "s/{{TEMPERATURE}}/$TEMPERATURE/g")
```

### Submit from template
```bash
pilotctl --json task submit "$AGENT_ADDR" --task "$TASK_DESC"
```

### Template with defaults
```bash
MODEL=${MODEL:-"gpt-4"}
TEMPERATURE=${TEMPERATURE:-0.7}
MAX_TOKENS=${MAX_TOKENS:-100}
```

### Template library
```bash
TEMPLATE_DIR="$HOME/.pilot/templates"
mkdir -p "$TEMPLATE_DIR"

# List templates
ls -1 "$TEMPLATE_DIR"/*.txt | sed 's|.*/||; s|\.txt$||'

# Load template
TEMPLATE=$(cat "$TEMPLATE_DIR/$TEMPLATE_NAME.txt")
```

## Workflow Example

Template-based submission system:

```bash
#!/bin/bash
set -e

TEMPLATE_DIR="$HOME/.pilot/templates"
mkdir -p "$TEMPLATE_DIR"

# Define template
cat > "$TEMPLATE_DIR/image-generation.txt" <<'EOF'
Generate image using model {{MODEL}}: {{PROMPT}}, size {{WIDTH}}x{{HEIGHT}}
EOF

# Instantiate template
instantiate_template() {
  TEMPLATE=$(cat "$TEMPLATE_DIR/$1.txt")

  while IFS= read -r VAR; do
    VAR_NAME=$(echo "$VAR" | sed 's/[{}]//g')
    VAR_VALUE="${!VAR_NAME}"

    [ -z "$VAR_VALUE" ] && { echo "Error: $VAR_NAME required"; exit 1; }

    VAR_VALUE_ESCAPED=$(echo "$VAR_VALUE" | sed 's/[&/\]/\\&/g')
    TEMPLATE=$(echo "$TEMPLATE" | sed "s|{{$VAR_NAME}}|$VAR_VALUE_ESCAPED|g")
  done < <(echo "$TEMPLATE" | grep -o '{{[^}]*}}' | sort -u)

  echo "$TEMPLATE"
}

# Submit
export AGENT="0:1234.5678.9abc"
export MODEL="stable-diffusion-xl"
export PROMPT="futuristic cityscape"
export WIDTH=1024
export HEIGHT=1024

TASK_DESC=$(instantiate_template "image-generation")
TASK_ID=$(pilotctl --json task submit "$AGENT" --task "$TASK_DESC" | jq -r '.task_id')

echo "Task submitted: $TASK_ID"
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, `jq` for JSON parsing, and template files in `~/.pilot/templates/`.
