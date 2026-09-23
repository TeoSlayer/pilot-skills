#!/usr/bin/env bash
# End-to-end test of muse/install.sh with a fake curl (tests/stubs/curl) that
# serves this checkout's skills and a stub official installer, and stub
# binaries. Covers: Muse frontmatter on installed copies only, the Muse target
# marker, PILOT_ALLOW_ROOT / PILOT_TRANSPORT for the official installer,
# PILOT_UPGRADE=1 restarting the node on the new binary, `curl | bash`.
# No network, nothing outside a temp HOME.
#   bash tests/muse-install.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STUBS="$ROOT/tests/stubs"
T="$(mktemp -d)"
FAILS=0
PASSES=0
OUT=""
RC=0
H="$T/home"
mkdir -p "$H" "$T/fakebin" "$T/tarball/pilot-skills-main"
cp "$STUBS/curl" "$T/fakebin/curl"
cp -R "$ROOT/skills" "$T/tarball/pilot-skills-main/skills"
UP="$H/workspace/skills/pilot-sandbox/scripts/pilot-up.sh"

cleanup() {
  if [ -f "$UP" ]; then
    env -i PATH="$PATH" HOME="$H" perl -e 'setpgrp(0, 0); exec @ARGV or die' bash "$UP" --stop > /dev/null 2>&1
  fi
  rm -rf "$T"
}
trap cleanup EXIT

pass() { PASSES=$((PASSES + 1)); }
failed() {
  FAILS=$((FAILS + 1))
  printf 'FAIL: %s\n' "$1"
  printf '%s\n' "$OUT" | sed 's/^/    | /'
}
expect() {
  local name="$1"
  shift
  if "$@"; then pass; else failed "$name"; fi
}
has() { grep -qF -- "$1" <<< "$OUT"; }
lacks() { ! grep -qF -- "$1" <<< "$OUT"; }

# install [VAR=value...] — run muse/install.sh (fed on stdin, as curl | bash
# does) with a clean environment. Sets OUT and RC.
install() {
  OUT="$(env -i PATH="$T/fakebin:$PATH" HOME="$H" \
    STUB_DIR="$STUBS" STUB_TARBALL_ROOT="$T/tarball" \
    PILOT_INSTALL_URL=https://stub.invalid/install.sh \
    PILOT_SOCKET="$H/pilot.sock" PILOT_UP_WAIT=8 STUB_HELP_PROXY=1 \
    "$@" perl -e 'setpgrp(0, 0); exec @ARGV or die' bash < "$ROOT/muse/install.sh" 2>&1)"
  RC=$?
}

echo "=== muse/install.sh tests ==="

# 1. Fresh install behind a proxy: skills, frontmatter, marker, binaries, node.
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 STUB_INSTALL_VERSION=v1.0.0
expect "fresh: rc 0" [ "$RC" = 0 ]
expect "fresh: node online" has "node online via the native path"
expect "fresh: done message" has "Done. Skills in $H/workspace/skills"
expect "fresh: credentials never printed" lacks "s3cret"
for s in pilotctl pilot-protocol pilot-sandbox; do
  f="$H/workspace/skills/$s/SKILL.md"
  expect "fresh: $s name rewritten" [ "$(sed -n 2p "$f")" = "name: \"${s//-/_}\"" ]
  expect "fresh: $s two-key frontmatter" [ "$(sed -n 4p "$f")" = "---" ]
done
expect "fresh: source skill files untouched" diff -rq "$ROOT/skills" "$T/tarball/pilot-skills-main/skills"
expect "fresh: Muse target marker" [ -f "$H/.pilot/targets/muse" ]
expect "fresh: marker is empty" [ ! -s "$H/.pilot/targets/muse" ]
if [ "$(id -u)" = 0 ]; then
  expect "root: PILOT_ALLOW_ROOT=1 passed" grep -q 'ALLOW_ROOT=1 ' "$H/.pilot/stub-installer.log"
else
  expect "non-root: no PILOT_ALLOW_ROOT" grep -q 'ALLOW_ROOT= ' "$H/.pilot/stub-installer.log"
fi
expect "proxy: PILOT_TRANSPORT=compat passed" grep -q 'TRANSPORT=compat' "$H/.pilot/stub-installer.log"

# 2. Rerun without PILOT_UPGRADE: nothing reinstalled, node already online.
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9
expect "rerun: rc 0" [ "$RC" = 0 ]
expect "rerun: installer skipped" has "Pilot already installed"
expect "rerun: node already online" has "node already online"

# 3. PILOT_UPGRADE=1 with a new release: the node restarts on the new binary.
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 PILOT_UPGRADE=1 STUB_INSTALL_VERSION=v2.0.0
expect "upgrade: rc 0" [ "$RC" = 0 ]
expect "upgrade: restart announced" has "The binaries changed: restarting the node"
expect "upgrade: old loop stopped" has "stopped respawn loop"
expect "upgrade: new version running" has "running v2.0.0"
expect "upgrade: no stale-version claim" lacks "running v1.0.0"

# 4. PILOT_UPGRADE=1 with the same release: no restart.
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 PILOT_UPGRADE=1 STUB_INSTALL_VERSION=v2.0.0
expect "same release: rc 0" [ "$RC" = 0 ]
expect "same release: says unchanged" has "did not change"
expect "same release: no restart" lacks "restarting the node"
expect "same release: still online" has "node already online"

# 5. Opt-out and skills-only: installed SKILL.md identical to the repo's.
install PILOT_SKILLS_ONLY=1 PILOT_MUSE_FRONTMATTER=0
expect "opt-out: rc 0" [ "$RC" = 0 ]
for s in pilotctl pilot-protocol pilot-sandbox; do
  expect "opt-out: $s untouched" cmp -s "$ROOT/skills/$s/SKILL.md" "$H/workspace/skills/$s/SKILL.md"
done

# 6. No proxy in the environment: PILOT_TRANSPORT is not forced.
rm -rf "$H/.pilot/bin" "$H/.pilot/stub-installer.log"
env -i PATH="$PATH" HOME="$H" perl -e 'setpgrp(0, 0); exec @ARGV or die' bash "$UP" --stop > /dev/null 2>&1
install PILOT_NO_START=1
expect "no proxy: rc 0" [ "$RC" = 0 ]
expect "no proxy: PILOT_TRANSPORT not set" grep -q 'TRANSPORT=$' "$H/.pilot/stub-installer.log"
expect "no start: says so" has "Node not started (PILOT_NO_START=1)"

echo "muse/install.sh: $PASSES passed, $FAILS failed"
[ "$FAILS" = 0 ]
