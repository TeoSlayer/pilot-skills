#!/usr/bin/env bash
# Unit tests for muse_frontmatter in muse/install.sh: the rewrite of installed
# SKILL.md frontmatter into the shape Muse loads (name: "x_y", one-line quoted
# description), with the body kept byte for byte.
#   bash tests/muse-frontmatter.test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=muse/install.sh source-path=SCRIPTDIR/..
source "$ROOT/muse/install.sh" # defines functions only; main runs only when executed
set +e

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAILS=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); }
failed() {
  FAILS=$((FAILS + 1))
  printf 'FAIL: %s\n' "$1"
  shift
  printf '  %s\n' "$@"
}

# check NAME FILE EXPECTED — FILE's content must equal EXPECTED exactly.
check() {
  local got
  got="$(cat "$2"; printf x)"
  got="${got%x}"
  if [ "$got" = "$3" ]; then pass; else failed "$1" "--- got:" "$got" "--- want:" "$3"; fi
}

# skill DIR CONTENT — write DIR/SKILL.md with CONTENT (printf %s, exact bytes).
skill() {
  mkdir -p "$T/$1"
  printf '%s' "$2" > "$T/$1/SKILL.md"
}

# 1. folded description (>), extra keys dropped, body byte for byte.
skill pilot-sandbox '---
name: pilot-sandbox
description: >
  Bring a node online from a "restricted" sandbox:
  no UDP, a C:\path and #hashes.

  Use this skill when:
  1. things fail
tags:
  - a
  - b
license: AGPL-3.0
metadata:
  version: "1.1"
---

# Title
body line with name: something
---
not frontmatter
'
muse_frontmatter "$T/pilot-sandbox/SKILL.md"
check "folded description" "$T/pilot-sandbox/SKILL.md" '---
name: "pilot_sandbox"
description: "Bring a node online from a \"restricted\" sandbox: no UDP, a C:\\path and #hashes. Use this skill when: 1. things fail"
---

# Title
body line with name: something
---
not frontmatter
'

# 2. plain single-line description, explicit name, body without a trailing newline.
skill plain '---
name: plain
description: Plain text with a # trailing comment
allowed-tools:
  - Bash
---
last line, no newline'
muse_frontmatter "$T/plain/SKILL.md" "custom_name"
check "plain scalar + explicit name + no trailing newline" "$T/plain/SKILL.md" '---
name: "custom_name"
description: "Plain text with a"
---
last line, no newline'

# 3. double-quoted with escapes, already in Muse shape: idempotent.
skill already-muse '---
name: "already_muse"
description: "Says \"hi\" and a back\\slash"
---
body
'
muse_frontmatter "$T/already-muse/SKILL.md"
check "double-quoted escapes" "$T/already-muse/SKILL.md" '---
name: "already_muse"
description: "Says \"hi\" and a back\\slash"
---
body
'
cp "$T/already-muse/SKILL.md" "$T/before"
muse_frontmatter "$T/already-muse/SKILL.md"
if cmp -s "$T/before" "$T/already-muse/SKILL.md"; then pass; else failed "idempotent" "$(diff "$T/before" "$T/already-muse/SKILL.md")"; fi

# 4. single-quoted with '' and a literal block (|-) in another key.
skill single-q "---
name: single-q
description: 'It''s \"fine\"'
compatibility: |-
  line one
  line two
---
b
"
muse_frontmatter "$T/single-q/SKILL.md"
check "single-quoted" "$T/single-q/SKILL.md" '---
name: "single_q"
description: "It'"'"'s \"fine\""
---
b
'

# 5. multi-line plain scalar and CRLF line endings.
skill crlf-skill $'---\r\nname: crlf-skill\r\ndescription: first part\r\n  second part\r\n---\r\nbody\r\n'
muse_frontmatter "$T/crlf-skill/SKILL.md"
check "CRLF + continuation" "$T/crlf-skill/SKILL.md" $'---\nname: "crlf_skill"\ndescription: "first part second part"\n---\nbody\r\n'

# 6. no description: a fallback, never an empty value.
skill no-desc '---
name: no-desc
---
x
'
muse_frontmatter "$T/no-desc/SKILL.md"
check "missing description" "$T/no-desc/SKILL.md" '---
name: "no_desc"
description: "Pilot Protocol skill no_desc"
---
x
'

# 7. no frontmatter, or an unclosed one: left alone.
skill no-front '# Just markdown
description: not yaml
'
muse_frontmatter "$T/no-front/SKILL.md"
check "no frontmatter" "$T/no-front/SKILL.md" '# Just markdown
description: not yaml
'
skill unclosed '---
name: unclosed
description: x
'
muse_frontmatter "$T/unclosed/SKILL.md"
check "unclosed frontmatter" "$T/unclosed/SKILL.md" '---
name: unclosed
description: x
'

# 8. over-long description: capped at 1024 bytes on a word boundary.
long="$(printf 'word%.0s ' $(seq 1 300))"
skill long-one "---
name: long-one
description: >
  $long
---
"
muse_frontmatter "$T/long-one/SKILL.md"
desc_line="$(sed -n 3p "$T/long-one/SKILL.md")"
value="${desc_line#description: \"}"
value="${value%\"}"
if [ "${#value}" -le 1024 ] && [ "${value%...}" != "$value" ] && [ "${value%word...}" != "$value" ]; then
  pass
else
  failed "long description capped" "got ${#value} chars: ${value: -40}"
fi

# 9. every real skill: a well-formed two-key frontmatter and an identical body.
for f in "$ROOT"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$f")")"
  mkdir -p "$T/real/$dir"
  cp "$f" "$T/real/$dir/SKILL.md"
  muse_frontmatter "$T/real/$dir/SKILL.md"
  out="$T/real/$dir/SKILL.md"
  close="$(awk 'NR > 1 && /^---$/ { print NR; exit }' "$f")"
  if [ "$(sed -n 1p "$out")" != "---" ] \
    || [ "$(sed -n 2p "$out")" != "name: \"${dir//-/_}\"" ] \
    || ! sed -n 3p "$out" | grep -Eq '^description: "([^"\\]|\\.)+"$' \
    || [ "$(sed -n 4p "$out")" != "---" ] \
    || ! cmp -s <(tail -n "+$((close + 1))" "$f") <(tail -n +5 "$out"); then
    failed "real skill $dir" "$(head -n 4 "$out")"
  else
    pass
  fi
done

echo "muse_frontmatter: $PASSES passed, $FAILS failed"
[ "$FAILS" = 0 ]
