#!/usr/bin/env bash
# install.sh — install the Pilot Protocol skills into a Meta Muse workspace,
# or any agent that loads SKILL.md folders from a directory.
#
#   curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash
#
# Environment (optional):
#   MUSE_SKILLS_DIR    destination folder (default ~/workspace/skills)
#   PILOT_SKILLS_REF   branch or tag of TeoSlayer/pilot-skills (default main)
#   PILOT_SKILLS       space-separated skill list (default: pilotctl pilot-protocol pilot-sandbox)
#
# curl honours HTTPS_PROXY, so this works from proxy-only sandboxes too.
set -euo pipefail

DEST="${MUSE_SKILLS_DIR:-$HOME/workspace/skills}"
REF="${PILOT_SKILLS_REF:-main}"
read -r -a SKILLS <<< "${PILOT_SKILLS:-pilotctl pilot-protocol pilot-sandbox}"
TARBALL="https://codeload.github.com/TeoSlayer/pilot-skills/tar.gz/refs/heads/$REF"

command -v curl >/dev/null || { echo "install: curl is required" >&2; exit 1; }
command -v tar  >/dev/null || { echo "install: tar is required" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching TeoSlayer/pilot-skills@$REF ..."
curl -fsSL "$TARBALL" | tar -xz -C "$TMP"
SRC="$(find "$TMP" -maxdepth 2 -type d -name skills | head -1)"
[ -d "$SRC" ] || { echo "install: archive did not contain a skills/ directory" >&2; exit 1; }

mkdir -p "$DEST"
for skill in "${SKILLS[@]}"; do
  if [ ! -f "$SRC/$skill/SKILL.md" ]; then
    echo "install: skill '$skill' not found in $REF" >&2; exit 1
  fi
  rm -rf "${DEST:?}/$skill"
  cp -R "$SRC/$skill" "$DEST/$skill"
  echo "installed $skill -> $DEST/$skill"
done

cat <<MSG

Done. ${#SKILLS[@]} skills in $DEST.
Next: install Pilot itself (pilotctl + pilot-daemon), then ask your agent about
Pilot Protocol. If the daemon cannot register from this sandbox, the
pilot-sandbox skill has the proxy-only recipe.
MSG
