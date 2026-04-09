#!/usr/bin/env bash
set -euo pipefail

# generate-catalog.sh — Parse SKILL.md frontmatter and produce skills.json
# No external dependencies beyond awk/sed. Works on bash 3+ (macOS default).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
OUTPUT="$SCRIPT_DIR/skills.json"

REPO_URL="https://github.com/TeoSlayer/pilot-skills/tree/main/skills"
CLAWHUB_URL="https://clawhub.ai/teoslayer"

# Map skill directory name → category
get_category() {
  case "$1" in
    pilot-protocol) echo "Core" ;;
    pilot-chat|pilot-broadcast|pilot-inbox|pilot-relay|pilot-group-chat|pilot-announce|pilot-voice-memo|pilot-translate|pilot-compress|pilot-priority-queue|pilot-receipt|pilot-thread) echo "Communication" ;;
    pilot-sync|pilot-share|pilot-dropbox|pilot-stream-data|pilot-chunk-transfer|pilot-dataset|pilot-model-share|pilot-backup|pilot-clipboard|pilot-archive) echo "File Transfer & Data" ;;
    pilot-auto-trust|pilot-trust-circle|pilot-verify|pilot-blocklist|pilot-audit-log|pilot-keychain|pilot-reputation|pilot-watchdog|pilot-quarantine|pilot-certificate) echo "Trust & Security" ;;
    pilot-task-router|pilot-task-monitor|pilot-task-chain|pilot-task-parallel|pilot-task-retry|pilot-task-template|pilot-cron|pilot-workflow|pilot-auction|pilot-escrow|pilot-sla|pilot-review) echo "Task & Workflow" ;;
    pilot-discover|pilot-directory|pilot-network-map|pilot-dns|pilot-health|pilot-announce-capabilities|pilot-matchmaker|pilot-mesh-status) echo "Discovery & Network" ;;
    pilot-event-bus|pilot-event-filter|pilot-event-replay|pilot-alert|pilot-metrics|pilot-event-log|pilot-webhook-bridge|pilot-presence) echo "Event & Pub/Sub" ;;
    pilot-mcp-bridge|pilot-a2a-bridge|pilot-http-proxy|pilot-slack-bridge|pilot-discord-bridge|pilot-email-bridge|pilot-github-bridge|pilot-database-bridge|pilot-s3-bridge|pilot-api-gateway) echo "Integration & Bridge" ;;
    pilot-swarm-join|pilot-consensus|pilot-leader-election|pilot-load-balancer|pilot-map-reduce|pilot-gossip|pilot-heartbeat-monitor|pilot-role-assign|pilot-swarm-config|pilot-formation) echo "Swarm & Coordination" ;;
    *-setup) echo "Setups" ;;
    *) echo "Uncategorized" ;;
  esac
}

# Parse one SKILL.md and emit a single-line TSV: dir_name\tcategory\tjson
parse_skill() {
  local dir_name="$1"
  local skill_file="$SKILLS_DIR/$dir_name/SKILL.md"
  [ ! -f "$skill_file" ] && return

  local parsed
  parsed=$(awk '
    BEGIN { in_fm=0; in_tags=0; in_desc=0; desc=""; name=""; version="1.0"; license="AGPL-3.0"; tags="" }
    /^---$/ { if(in_fm) { exit } else { in_fm=1; next } }
    !in_fm { next }
    /^name:/ { name=$2; in_tags=0; in_desc=0; next }
    /^license:/ { license=$2; in_tags=0; in_desc=0; next }
    /^[[:space:]]+version:/ { v=$2; gsub(/"/, "", v); version=v; next }
    /^tags:/ { in_tags=1; in_desc=0; next }
    in_tags && /^[[:space:]]*-[[:space:]]/ {
      t=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", t); gsub(/[[:space:]]*$/, "", t)
      if (tags != "") tags = tags "," t; else tags = t
      next
    }
    in_tags && /^[a-z]/ { in_tags=0 }
    /^description:/ {
      in_desc=1; in_tags=0
      sub(/^description:[[:space:]]*>?[[:space:]]*/, "")
      if (length($0) > 0) desc=$0
      next
    }
    in_desc && /^[[:space:]]/ {
      line=$0; sub(/^[[:space:]]+/, "", line)
      if (desc != "") desc = desc " " line; else desc = line
      next
    }
    in_desc && /^[a-z]/ { in_desc=0 }
    END {
      idx = index(desc, "Use this skill")
      if (idx > 0) desc = substr(desc, 1, idx-1)
      gsub(/[[:space:]]+$/, "", desc)
      n = split(tags, tarr, ",")
      tjson = ""
      for (i=1; i<=n; i++) {
        if (i>1) tjson = tjson ","
        tjson = tjson "\"" tarr[i] "\""
      }
      printf "%s\t%s\t%s\t%s\t[%s]", name, desc, version, license, tjson
    }
  ' "$skill_file")

  [ -z "$parsed" ] && return

  local name desc version license tags_json
  name=$(echo "$parsed" | cut -f1)
  desc=$(echo "$parsed" | cut -f2)
  version=$(echo "$parsed" | cut -f3)
  license=$(echo "$parsed" | cut -f4)
  tags_json=$(echo "$parsed" | cut -f5)

  [ -z "$name" ] && name="$dir_name"

  desc=$(printf '%s' "$desc" | sed 's/\\/\\\\/g; s/"/\\"/g')

  local clawhub_slug="$name"

  local category
  category=$(get_category "$dir_name")

  printf '%s\t%s\t{"slug":"%s","name":"%s","description":"%s","tags":%s,"version":"%s","license":"%s","clawhub_slug":"%s","clawhub_url":"%s/%s","source":"%s/%s","install":"clawhub install %s"}\n' \
    "$dir_name" "$category" \
    "$dir_name" "$name" "$desc" "$tags_json" "$version" "$license" \
    "$clawhub_slug" "$CLAWHUB_URL" "$clawhub_slug" "$REPO_URL" "$dir_name" "$clawhub_slug"
}

echo "Generating skills catalog..." >&2

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

total=0
for dir in "$SKILLS_DIR"/*/; do
  dir_name=$(basename "$dir")
  result=$(parse_skill "$dir_name" || true)
  if [ -n "$result" ]; then
    echo "$result" >> "$TMPFILE"
    total=$((total + 1))
  fi
done

# Use awk to assemble clean JSON from the TSV (avoids subshell variable issues)
GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

awk -F'\t' -v generated="$GENERATED_AT" -v total="$total" -v categories="Core|Communication|File Transfer & Data|Trust & Security|Task & Workflow|Discovery & Network|Event & Pub/Sub|Integration & Bridge|Swarm & Coordination|Setups" '
BEGIN {
  n = split(categories, cat_names, "|")
  for (i=1; i<=n; i++) {
    cat_order[i] = cat_names[i]
    cat_count[cat_names[i]] = 0
  }
}
{
  dir = $1; cat = $2; json = $3
  cat_count[cat]++
  idx = cat_count[cat]
  skills[cat, idx] = json
}
END {
  printf "{\n"
  printf "  \"generated_at\": \"%s\",\n", generated
  printf "  \"version\": \"1.0.0\",\n"
  printf "  \"total\": %d,\n", total
  printf "  \"categories\": [\n"

  first_cat = 1
  for (c=1; c<=n; c++) {
    cat = cat_order[c]
    if (cat_count[cat] == 0) continue
    if (!first_cat) printf ",\n"
    first_cat = 0

    slug = tolower(cat)
    gsub(/ & /, "-", slug)
    gsub(/ /, "-", slug)

    printf "    {\n"
    printf "      \"name\": \"%s\",\n", cat
    printf "      \"slug\": \"%s\",\n", slug
    printf "      \"skills\": [\n"

    for (s=1; s<=cat_count[cat]; s++) {
      if (s > 1) printf ",\n"
      printf "        %s", skills[cat, s]
    }
    printf "\n      ]\n"
    printf "    }"
  }
  printf "\n  ]\n"
  printf "}\n"
}
' "$TMPFILE" > "$OUTPUT.tmp"

# Pretty-print the JSON for readable diffs
python3 -m json.tool --indent 2 "$OUTPUT.tmp" > "$OUTPUT"
rm -f "$OUTPUT.tmp"

echo "Generated $OUTPUT with $total skills" >&2
