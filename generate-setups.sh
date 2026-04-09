#!/usr/bin/env bash
set -eo pipefail

# generate-setups.sh — Parse README.md + SKILL.md from pilot-*-setup directories
# and produce setups.json. No external dependencies beyond awk/sed.
# Works on bash 3+ (macOS default).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
OUTPUT="$SCRIPT_DIR/setups.json"

TMPDIR_WORK=$(mktemp -d)
trap "rm -rf $TMPDIR_WORK" EXIT

# Escape a string for JSON (backslashes, double quotes, newlines, tabs)
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# Extract the "## Try It" or "## Workflow Example" code block from a file
extract_code_block() {
  local file="$1"
  local heading="$2"
  awk -v heading="$heading" '
    BEGIN { found=0; in_block=0 }
    $0 ~ "^## " heading { found=1; next }
    found && /^```/ {
      if (in_block) exit
      in_block=1; next
    }
    found && !in_block && /^## / { exit }
    in_block { print }
  ' "$file"
}

# Extract all setup commands from README.md "## Setup" section
extract_setup_section() {
  local file="$1"
  awk '
    BEGIN { found=0; in_block=0 }
    /^## Setup/ { found=1; next }
    found && /^## / && !/^## Setup/ { exit }
    found && /^```bash/ { in_block=1; next }
    found && in_block && /^```/ { in_block=0; next }
    found && in_block { print }
  ' "$file"
}

# Parse one setup directory and produce JSON
parse_setup() {
  local dir_name="$1"
  local dir_path="$SKILLS_DIR/$dir_name"
  local readme="$dir_path/README.md"
  local skill="$dir_path/SKILL.md"

  [ ! -f "$readme" ] && return
  [ ! -f "$skill" ] && return

  # --- Extract slug from directory name ---
  local slug="${dir_name#pilot-}"       # remove "pilot-" prefix
  slug="${slug%-setup}"                  # remove "-setup" suffix

  # --- Parse README.md for name, description, difficulty, agent_count ---
  local name description difficulty agent_count

  # Name from first heading
  name=$(awk '/^# / { sub(/^# /, ""); print; exit }' "$readme")

  # Remove " Setup" suffix from name if present
  name="${name% Setup}"

  # Description: paragraph after the first heading (before **Difficulty**)
  description=$(awk '
    BEGIN { past_heading=0 }
    /^# / { past_heading=1; next }
    past_heading && /^\*\*Difficulty/ { exit }
    past_heading && /^$/ { next }
    past_heading && /^[^#]/ {
      if (desc != "") desc = desc " "
      desc = desc $0
    }
    END { print desc }
  ' "$readme")

  # Difficulty and agent count from **Difficulty:** line
  difficulty=$(awk '/^\*\*Difficulty:\*\*/ {
    match($0, /Difficulty:\*\* ([A-Za-z]+)/, a)
    if (RSTART) print tolower(a[1])
  }' "$readme" 2>/dev/null || true)

  # Fallback: simpler parsing for macOS awk (no match groups)
  if [ -z "$difficulty" ]; then
    difficulty=$(awk '/^\*\*Difficulty:\*\*/ {
      sub(/.*Difficulty:\*\* */, "")
      sub(/ *\|.*/, "")
      print tolower($0)
    }' "$readme")
  fi

  agent_count=$(awk '/^\*\*Difficulty:\*\*/ {
    sub(/.*Agents:\*\* */, "")
    sub(/[^0-9].*/, "")
    print
  }' "$readme" 2>/dev/null || echo "3")

  [ -z "$difficulty" ] && difficulty="beginner"
  [ -z "$agent_count" ] && agent_count="3"

  # Tagline: first sentence of description (up to first period)
  local tagline
  tagline=$(printf '%s' "$description" | sed 's/\. .*/\./' | head -c 100)

  # --- Parse SKILL.md roles table ---
  # Format: | role_id | `<prefix>-role_id` | skill1, skill2 | Purpose text |
  local roles_tsv="$TMPDIR_WORK/${slug}_roles.tsv"
  awk '
    BEGIN { in_table=0 }
    /^## Roles/ { in_table=1; next }
    in_table && /^## / { exit }
    in_table && /^\|/ && !/Role.*Hostname/ && !/^[|][-]/ {
      gsub(/`/, "")
      n = split($0, cols, "|")
      if (n >= 5) {
        role = cols[2]; gsub(/^[ \t]+|[ \t]+$/, "", role)
        hostname = cols[3]; gsub(/^[ \t]+|[ \t]+$/, "", hostname)
        skills = cols[4]; gsub(/^[ \t]+|[ \t]+$/, "", skills)
        purpose = cols[5]; gsub(/^[ \t]+|[ \t]+$/, "", purpose)
        if (role != "" && role != "Role") {
          printf "%s\t%s\t%s\t%s\n", role, hostname, skills, purpose
        }
      }
    }
  ' "$skill" > "$roles_tsv"

  # --- Parse SKILL.md manifest JSON blocks for each role ---
  # Extract role descriptions from manifest templates
  local manifests_file="$TMPDIR_WORK/${slug}_manifests.txt"
  awk '
    BEGIN { in_manifest=0; role="" }
    /^### / && !/^### [0-9]/ {
      role = $2
      next
    }
    /^```json/ { in_manifest=1; next }
    in_manifest && /^```/ { in_manifest=0; next }
    in_manifest {
      print role "\t" $0
    }
  ' "$skill" > "$manifests_file"

  # --- Parse data flows from SKILL.md "## Data Flows" section ---
  # Format: - `from -> to` : description (port NNNN)
  # or:     - `from → to` : description (port NNNN)
  # Output TSV: from\tto\tdescription\tport
  local flows_file="$TMPDIR_WORK/${slug}_flows.tsv"
  awk '
    BEGIN { found=0 }
    /^## Data Flows/ { found=1; next }
    found && /^## / { exit }
    found && /[-]>|→/ {
      line = $0
      # Remove leading "- " and backticks
      gsub(/`/, "", line)
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)

      # Split on " : " to get "from -> to" and "description (port N)"
      idx = index(line, " : ")
      if (idx == 0) next
      left = substr(line, 1, idx-1)
      right = substr(line, idx+3)

      # Parse from/to — handle both -> and → (Unicode)
      from_role = left
      to_role = left
      if (index(left, " -> ") > 0) {
        split(left, parts, " -> ")
        from_role = parts[1]
        to_role = parts[2]
      } else {
        # Try → (multi-byte)
        n = split(left, parts, " ")
        if (n >= 3) {
          from_role = parts[1]
          to_role = parts[n]
        }
      }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", from_role)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", to_role)

      # Parse description and port
      desc = right
      port = "1002"
      if (match(right, /\(port [0-9]+\)/)) {
        port_str = substr(right, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", port_str)
        port = port_str
        desc = substr(right, 1, RSTART-1)
      }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)

      printf "%s\t%s\t%s\t%s\n", from_role, to_role, desc, port
    }
  ' "$skill" > "$flows_file"

  # --- Extract quick_start from README.md ---
  local setup_cmds="$TMPDIR_WORK/${slug}_setup.txt"
  extract_setup_section "$readme" > "$setup_cmds"

  # --- Extract workflow from README.md "## Try It" section ---
  local workflow_file="$TMPDIR_WORK/${slug}_workflow.txt"
  extract_code_block "$readme" "Try It" > "$workflow_file"

  # If no "Try It", try "Workflow Example" from SKILL.md
  if [ ! -s "$workflow_file" ]; then
    extract_code_block "$skill" "Workflow Example" > "$workflow_file"
  fi

  # --- Build JSON ---
  local json_file="$TMPDIR_WORK/${slug}.json"

  # Escape strings
  local esc_name esc_tagline esc_desc
  esc_name=$(json_escape "$name")
  esc_tagline=$(json_escape "$tagline")
  esc_desc=$(json_escape "$description")

  # Start setup entry
  printf '    {\n' > "$json_file"
  printf '      "slug": "%s",\n' "$slug" >> "$json_file"
  printf '      "name": "%s",\n' "$esc_name" >> "$json_file"
  printf '      "tagline": "%s",\n' "$esc_tagline" >> "$json_file"
  printf '      "description": "%s",\n' "$esc_desc" >> "$json_file"
  printf '      "difficulty": "%s",\n' "$difficulty" >> "$json_file"
  printf '      "agent_count": %s,\n' "$agent_count" >> "$json_file"

  # Collect all unique skills
  local all_skills=""
  while IFS=$'\t' read -r role_id hostname skills purpose; do
    # Split skills by comma
    local IFS_OLD="$IFS"
    IFS=','
    for s in $skills; do
      s=$(echo "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ -n "$s" ]; then
        if [ -z "$all_skills" ]; then
          all_skills="$s"
        elif ! echo "$all_skills" | grep -q "$s"; then
          all_skills="$all_skills,$s"
        fi
      fi
    done
    IFS="$IFS_OLD"
  done < "$roles_tsv"

  # skills_used array
  printf '      "skills_used": [' >> "$json_file"
  local first=1
  IFS=','
  for s in $all_skills; do
    if [ $first -eq 1 ]; then
      first=0
    else
      printf ',' >> "$json_file"
    fi
    printf '\n        "%s"' "$s" >> "$json_file"
  done
  unset IFS
  printf '\n      ],\n' >> "$json_file"

  # --- Agents array ---
  printf '      "agents": [\n' >> "$json_file"
  local agent_first=1
  while IFS=$'\t' read -r role_id hostname skills purpose; do
    if [ $agent_first -eq 1 ]; then
      agent_first=0
    else
      printf ',\n' >> "$json_file"
    fi

    # Get role_name and description from manifest templates
    local role_name="" role_desc=""
    role_name=$(awk -F'\t' -v role="$role_id" '
      $1 == role && /role_name/ {
        sub(/.*"role_name"[[:space:]]*:[[:space:]]*"/, "")
        sub(/".*/, "")
        print
        exit
      }
    ' "$manifests_file")
    [ -z "$role_name" ] && role_name="$purpose"

    role_desc=$(awk -F'\t' -v role="$role_id" '
      $1 == role && /"description"/ && !/data_flows/ && !/peers/ {
        sub(/.*"description"[[:space:]]*:[[:space:]]*"/, "")
        sub(/"[,]?$/, "")
        print
        exit
      }
    ' "$manifests_file")
    [ -z "$role_desc" ] && role_desc="$purpose"

    local esc_role_name esc_role_desc
    esc_role_name=$(json_escape "$role_name")
    esc_role_desc=$(json_escape "$role_desc")

    printf '        {\n' >> "$json_file"
    printf '          "id": "%s",\n' "$role_id" >> "$json_file"
    printf '          "hostname": "<your-prefix>-%s",\n' "$role_id" >> "$json_file"
    printf '          "role": "%s",\n' "$esc_role_name" >> "$json_file"
    printf '          "description": "%s",\n' "$esc_role_desc" >> "$json_file"

    # Skills array for this agent
    printf '          "skills": [' >> "$json_file"
    local sfirst=1
    local IFS_OLD="$IFS"
    IFS=','
    for s in $skills; do
      s=$(echo "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ -n "$s" ]; then
        if [ $sfirst -eq 1 ]; then
          sfirst=0
        else
          printf ',' >> "$json_file"
        fi
        printf '\n            "%s"' "$s" >> "$json_file"
      fi
    done
    IFS="$IFS_OLD"
    printf '\n          ],\n' >> "$json_file"

    # Setup commands for this agent
    printf '          "setup_commands": [\n' >> "$json_file"
    printf '            "clawhub install %s",\n' "$(echo "$skills" | sed 's/,/ /g; s/  */ /g; s/^ *//; s/ *$//')" >> "$json_file"
    printf '            "pilotctl set-hostname <your-prefix>-%s"' "$role_id" >> "$json_file"

    # Handshakes from manifest
    local handshakes=""
    handshakes=$(awk -F'\t' -v role="$role_id" '
      $1 == role && /handshakes_needed/ {
        line = $2
        gsub(/.*\[/, "", line)
        gsub(/\].*/, "", line)
        gsub(/"/, "", line)
        gsub(/<prefix>/, "<your-prefix>", line)
        print line
      }
    ' "$manifests_file")

    if [ -n "$handshakes" ]; then
      printf ',\n            "",\n' >> "$json_file"
      printf '            "# Establish trust with peers (both sides must handshake)"' >> "$json_file"
      IFS=','
      for h in $handshakes; do
        h=$(echo "$h" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$h" ]; then
          printf ',\n            "pilotctl handshake %s \\"setup: %s\\""' "$h" "$slug" >> "$json_file"
        fi
      done
      unset IFS
    fi

    printf '\n          ]\n' >> "$json_file"
    printf '        }' >> "$json_file"
  done < "$roles_tsv"
  printf '\n      ],\n' >> "$json_file"

  # --- Data flows array ---
  printf '      "data_flows": [\n' >> "$json_file"
  local flow_first=1
  while IFS=$'\t' read -r from_role to_role flow_desc flow_port; do
    [ -z "$from_role" ] && continue

    # Map role names to hostnames
    local from_host to_host
    if [ "$from_role" = "external" ] || [ "$from_role" = "humans" ]; then
      from_host="external"
    else
      from_host="<your-prefix>-$from_role"
    fi
    if [ "$to_role" = "external" ] || [ "$to_role" = "humans" ]; then
      to_host="external"
    else
      to_host="<your-prefix>-$to_role"
    fi

    # Capitalize first word of description
    local esc_flow_desc
    esc_flow_desc=$(json_escape "$flow_desc")

    if [ $flow_first -eq 1 ]; then
      flow_first=0
    else
      printf ',\n' >> "$json_file"
    fi
    printf '        {\n' >> "$json_file"
    printf '          "from": "%s",\n' "$from_host" >> "$json_file"
    printf '          "to": "%s",\n' "$to_host" >> "$json_file"
    printf '          "description": "%s",\n' "$esc_flow_desc" >> "$json_file"
    printf '          "port": "%s"\n' "$flow_port" >> "$json_file"
    printf '        }' >> "$json_file"
  done < "$flows_file"
  printf '\n      ],\n' >> "$json_file"

  # --- Quick start array from README setup section ---
  printf '      "quick_start": [\n' >> "$json_file"
  local qs_first=1
  # Build quick_start from the README setup code blocks + trust section
  printf '        "# Replace <your-prefix> with a unique name for your deployment (e.g. acme)"' >> "$json_file"
  while IFS= read -r line; do
    printf ',\n        ' >> "$json_file"
    local esc_line
    esc_line=$(json_escape "$line")
    printf '"%s"' "$esc_line" >> "$json_file"
  done < "$setup_cmds"
  printf '\n      ],\n' >> "$json_file"

  # --- Workflow array ---
  printf '      "workflow": [\n' >> "$json_file"
  local wf_first=1
  while IFS= read -r line; do
    if [ $wf_first -eq 1 ]; then
      wf_first=0
    else
      printf ',\n' >> "$json_file"
    fi
    local esc_line
    esc_line=$(json_escape "$line")
    printf '        "%s"' "$esc_line" >> "$json_file"
  done < "$workflow_file"
  printf '\n      ]\n' >> "$json_file"

  printf '    }' >> "$json_file"

  echo "$slug"
}

echo "Generating setups catalog..." >&2

# Collect all setup directories
total=0
setup_files=""
for dir in "$SKILLS_DIR"/pilot-*-setup/; do
  [ ! -d "$dir" ] && continue
  dir_name=$(basename "$dir")
  slug=$(parse_setup "$dir_name" || true)
  if [ -n "$slug" ]; then
    total=$((total + 1))
    if [ -z "$setup_files" ]; then
      setup_files="$slug"
    else
      setup_files="$setup_files $slug"
    fi
  fi
done

# Assemble final JSON
{
  printf '{\n'
  printf '  "version": "1.0.0",\n'
  printf '  "total": %d,\n' "$total"
  printf '  "setups": [\n'

  first=1
  for slug in $setup_files; do
    json_file="$TMPDIR_WORK/${slug}.json"
    [ ! -f "$json_file" ] && continue
    if [ $first -eq 1 ]; then
      first=0
    else
      printf ',\n'
    fi
    cat "$json_file"
  done

  printf '\n  ]\n'
  printf '}\n'
} > "$OUTPUT.tmp"

# Pretty-print the JSON for readable diffs
python3 -m json.tool --indent 2 "$OUTPUT.tmp" > "$OUTPUT"
rm -f "$OUTPUT.tmp"

echo "Generated $OUTPUT with $total setups" >&2
