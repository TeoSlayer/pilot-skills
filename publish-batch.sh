#!/bin/bash
# publish-batch.sh — Publish skills to ClawHub respecting 5-new-skills/hour rate limit
set -uo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
LOG="$(dirname "$0")/publish.log"

echo "=== ClawHub Batch Publisher ===" | tee "$LOG"
echo "Started: $(date)" | tee -a "$LOG"

NEW_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

for skill_dir in "$SKILLS_DIR"/*/; do
  slug=$(basename "$skill_dir")
  EXTRA_FLAGS=""

  # Core skill is registered as "pilotprotocol" on ClawHub (no hyphen)
  if [ "$slug" = "pilot-protocol" ]; then
    EXTRA_FLAGS="--slug pilotprotocol"
  fi

  echo "Publishing $slug..." | tee -a "$LOG"

  OUTPUT=$(clawhub publish "$skill_dir" --version 1.0.0 --changelog "Initial release" $EXTRA_FLAGS 2>&1)
  EXIT_CODE=$?

  if echo "$OUTPUT" | grep -q "Published"; then
    NEW_COUNT=$((NEW_COUNT + 1))
    echo "  NEW: $slug (total new: $NEW_COUNT)" | tee -a "$LOG"

    # After every 5 new publishes, wait for rate limit reset
    if [ $((NEW_COUNT % 5)) -eq 0 ]; then
      echo "  Rate limit pause — waiting 61 min ($(date))..." | tee -a "$LOG"
      sleep 3660
      echo "  Resumed ($(date))" | tee -a "$LOG"
    fi
  elif echo "$OUTPUT" | grep -qi "rate limit"; then
    echo "  Rate limited on $slug — waiting 61 min..." | tee -a "$LOG"
    sleep 3660
    echo "  Retrying $slug..." | tee -a "$LOG"
    OUTPUT2=$(clawhub publish "$skill_dir" --version 1.0.0 --changelog "Initial release" $EXTRA_FLAGS 2>&1)
    if echo "$OUTPUT2" | grep -q "Published"; then
      NEW_COUNT=$((NEW_COUNT + 1))
      echo "  NEW (retry): $slug (total new: $NEW_COUNT)" | tee -a "$LOG"
      if [ $((NEW_COUNT % 5)) -eq 0 ]; then
        echo "  Rate limit pause — waiting 61 min..." | tee -a "$LOG"
        sleep 3660
      fi
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo "  FAILED (retry): $slug: $OUTPUT2" | tee -a "$LOG"
    fi
  elif echo "$OUTPUT" | grep -qi "already\|exists\|conflict\|synced\|version.*exists"; then
    SKIP_COUNT=$((SKIP_COUNT + 1))
    echo "  SKIP (exists): $slug" | tee -a "$LOG"
  elif [ $EXIT_CODE -eq 0 ]; then
    SKIP_COUNT=$((SKIP_COUNT + 1))
    echo "  OK: $slug" | tee -a "$LOG"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  FAILED: $slug: $OUTPUT" | tee -a "$LOG"
  fi
done

echo "" | tee -a "$LOG"
echo "=== DONE ===" | tee -a "$LOG"
echo "New: $NEW_COUNT, Skipped: $SKIP_COUNT, Failed: $FAIL_COUNT" | tee -a "$LOG"
echo "Finished: $(date)" | tee -a "$LOG"
