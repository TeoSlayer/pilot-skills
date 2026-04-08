#!/bin/bash
# test-skills.sh — Validate all Pilot Protocol skills
# Checks: YAML frontmatter, pilotctl command existence, --json flags, structure
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
ERRORS=()

# Known valid commands extracted from pilotctl help
VALID_COMMANDS=(
  init config
  daemon
  register lookup rotate-key set-public set-private deregister
  find set-hostname clear-hostname set-tags clear-tags enable-tasks disable-tasks
  connect send recv send-file send-message subscribe publish
  task
  handshake approve reject untrust pending trust
  connections disconnect
  received inbox
  info peers ping traceroute bench listen broadcast context
  gateway
  set-webhook clear-webhook
  set-visibility
  network
)

is_valid_command() {
  local cmd="$1"
  for valid in "${VALID_COMMANDS[@]}"; do
    [ "$cmd" = "$valid" ] && return 0
  done
  return 1
}

# Extract only lines inside ```bash ... ``` code blocks
extract_code_blocks() {
  awk '/^```bash/{inside=1; next} /^```/{inside=0; next} inside{print NR": "$0}' "$1"
}

echo "=== Pilot Skills Test Suite ==="
echo ""

SKILL_COUNT=$(find "$SKILLS_DIR" -name "SKILL.md" -type f | wc -l | tr -d ' ')
echo "Found $SKILL_COUNT skills to test"
echo ""

# Test 1: YAML Frontmatter
echo "--- Test 1: YAML Frontmatter ---"
T1_PASS=0
for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")

  if ! head -1 "$skill_file" | grep -q '^---$'; then
    ERRORS+=("$skill_name: Missing YAML frontmatter opener")
    continue
  fi

  if ! awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$skill_file"; then
    ERRORS+=("$skill_name: Unclosed YAML frontmatter")
    continue
  fi

  frontmatter=$(awk '/^---$/{ if(n++) exit; next } n' "$skill_file")

  for field in "name:" "description:" "tags:" "license:" "allowed-tools:"; do
    if ! echo "$frontmatter" | grep -q "$field"; then
      ERRORS+=("$skill_name: Missing field: $field")
    fi
  done

  yaml_name=$(echo "$frontmatter" | grep '^name:' | head -1 | sed 's/^name: *//')
  if [ "$yaml_name" != "$skill_name" ]; then
    ERRORS+=("$skill_name: name='$yaml_name' doesn't match directory")
  fi

  T1_PASS=$((T1_PASS + 1))
done
echo "  Frontmatter: $T1_PASS/$SKILL_COUNT passed"

# Test 2: pilotctl commands (code blocks only)
echo ""
echo "--- Test 2: pilotctl Command Validation ---"
CMD_PASS=0
CMD_FAIL=0
CMD_TOTAL=0

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")

  commands=$(extract_code_blocks "$skill_file" | \
    grep -oE 'pilotctl[[:space:]]+(--json[[:space:]]+)?[a-z][-a-z]*' 2>/dev/null | \
    sed 's/pilotctl[[:space:]]*\(--json[[:space:]]*\)\{0,1\}//' | sort -u)

  for cmd in $commands; do
    CMD_TOTAL=$((CMD_TOTAL + 1))
    if is_valid_command "$cmd"; then
      CMD_PASS=$((CMD_PASS + 1))
    else
      ERRORS+=("$skill_name: Unknown command 'pilotctl $cmd'")
      CMD_FAIL=$((CMD_FAIL + 1))
    fi
  done
done
echo "  Commands: $CMD_PASS valid, $CMD_FAIL invalid ($CMD_TOTAL total)"

# Test 3: --json flag (code blocks only, skip pilot-protocol core skill)
echo ""
echo "--- Test 3: --json Flag Placement ---"
JSON_ISSUES=0

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  # Core skill shows reference syntax — skip strict --json check
  [ "$skill_name" = "pilot-protocol" ] && continue

  bad_calls=$(extract_code_blocks "$skill_file" | \
    grep -E 'pilotctl\s+[a-z]' 2>/dev/null | \
    grep -vE 'pilotctl\s+--json' | \
    grep -vE '^\s*#' || true)

  if [ -n "$bad_calls" ]; then
    while IFS= read -r line; do
      linenum=$(echo "$line" | cut -d: -f1)
      ERRORS+=("$skill_name:$linenum: Missing --json flag")
      JSON_ISSUES=$((JSON_ISSUES + 1))
    done <<< "$bad_calls"
  fi
done
echo "  Issues: $JSON_ISSUES"

# Test 4: Size check (pilot-protocol allowed up to 500)
echo ""
echo "--- Test 4: Size Check ---"
SIZE_WARN=0

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  lines=$(wc -l < "$skill_file" | tr -d ' ')

  max=200
  [ "$skill_name" = "pilot-protocol" ] && max=500

  if [ "$lines" -gt "$max" ]; then
    ERRORS+=("$skill_name: $lines lines (max $max)")
    SIZE_WARN=$((SIZE_WARN + 1))
  fi
done
echo "  Oversized: $SIZE_WARN"

# Test 5: Dependencies section
echo ""
echo "--- Test 5: Dependencies Section ---"
DEP_FAIL=0

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  # Core skill has dependencies in references
  [ "$skill_name" = "pilot-protocol" ] && continue

  if ! grep -qi '## *depend' "$skill_file" 2>/dev/null; then
    ERRORS+=("$skill_name: Missing ## Dependencies section")
    DEP_FAIL=$((DEP_FAIL + 1))
  fi
done
echo "  Missing: $DEP_FAIL"

# Test 6: Workflow example
echo ""
echo "--- Test 6: Workflow Example ---"
WF_FAIL=0

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  [ "$skill_name" = "pilot-protocol" ] && continue

  if ! grep -qi '## *workflow' "$skill_file" 2>/dev/null; then
    ERRORS+=("$skill_name: Missing ## Workflow section")
    WF_FAIL=$((WF_FAIL + 1))
  fi
done
echo "  Missing: $WF_FAIL"

# Summary
echo ""
echo "=== SUMMARY ==="
TOTAL_ERRORS=${#ERRORS[@]}
if [ "$TOTAL_ERRORS" -eq 0 ]; then
  echo "ALL TESTS PASSED ($SKILL_COUNT skills, $CMD_TOTAL commands)"
  exit 0
else
  echo "FAILURES: $TOTAL_ERRORS"
  echo ""
  for err in "${ERRORS[@]}"; do
    echo "  FAIL: $err"
  done
  exit 1
fi
