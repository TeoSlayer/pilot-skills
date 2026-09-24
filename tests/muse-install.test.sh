#!/usr/bin/env bash
# End-to-end test of muse/install.sh with a fake curl (tests/stubs/curl) that
# serves this checkout's skills and a stub official installer, and stub
# binaries. Covers: Muse frontmatter on installed copies only, the Muse target
# marker, PILOT_ALLOW_ROOT / PILOT_TRANSPORT for the official installer,
# PILOT_UPGRADE=1 restarting the node on the new binary (also one started by
# hand, and saying so when it cannot), `curl | bash`.
# No network, nothing outside a temp HOME (PILOT_SOCKET included).
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
RELAY="127.0.0.1:$((40000 + RANDOM % 10000))"
mkdir -p "$H" "$T/fakebin" "$T/tarball/pilot-skills-main"
cp "$STUBS/curl" "$T/fakebin/curl"
cp -R "$ROOT/skills" "$T/tarball/pilot-skills-main/skills"
UP="$H/workspace/skills/pilot-sandbox/scripts/pilot-up.sh"

# stop_node — pilot-up.sh --stop for the test HOME (never the default socket).
stop_node() {
  env -i PATH="$PATH" HOME="$H" PILOT_SOCKET="$H/pilot.sock" PILOT_RELAY_LISTEN="$RELAY" \
    perl -e 'setpgrp(0, 0); exec @ARGV or die' bash "$UP" --stop > /dev/null 2>&1
}

cleanup() {
  if [ -f "$UP" ]; then stop_node; fi
  pkill -f "$T/" 2> /dev/null
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
not() { ! "$@"; }

# install [VAR=value...] — run muse/install.sh (fed on stdin, as curl | bash
# does) with a clean environment, stub binaries whose pilot-daemon has -proxy
# and -proxy-cmd (the next release), and the egress relay (if one is started)
# on a random port. Sets OUT and RC.
install() {
  OUT="$(env -i PATH="$T/fakebin:$PATH" HOME="$H" \
    STUB_DIR="$STUBS" STUB_TARBALL_ROOT="$T/tarball" \
    PILOT_INSTALL_URL=https://stub.invalid/install.sh \
    PILOT_SOCKET="$H/pilot.sock" PILOT_UP_WAIT=8 STUB_HELP_PROXY=1 STUB_HELP_PROXY_CMD=1 \
    PILOT_RELAY_LISTEN="$RELAY" \
    "$@" perl -e 'setpgrp(0, 0); exec @ARGV or die' bash < "$ROOT/muse/install.sh" 2>&1)"
  RC=$?
}

echo "=== muse/install.sh tests ==="

# 1. Fresh install behind a proxy: skills, frontmatter, marker, binaries, node.
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 STUB_INSTALL_VERSION=v1.0.0
expect "fresh: rc 0" [ "$RC" = 0 ]
expect "fresh: node online" has "node online via the native path"
expect "fresh: done message" has "Done. Skills in $H/workspace/skills"
expect "fresh: done message says what to do after a credential rotation" has "the proxy credentials rotated: run the same command from a fresh shell"
expect "fresh: the node re-reads rotating credentials (-proxy-cmd)" has "credentials re-read by pilot-daemon (-proxy-cmd)"
expect "fresh: done message says so" has "The node re-reads the rotating proxy credentials itself"
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
expect "upgrade: restart announced" has "Restarting the node on the new pilot-daemon"
expect "upgrade: old loop stopped" has "stopped respawn loop"
expect "upgrade: new version running" has "running v2.0.0"
expect "upgrade: no stale-version claim" lacks "running v1.0.0"

# 4. PILOT_UPGRADE=1 with the same release: no restart.
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 PILOT_UPGRADE=1 STUB_INSTALL_VERSION=v2.0.0
expect "same release: rc 0" [ "$RC" = 0 ]
expect "same release: says unchanged" has "did not change"
expect "same release: no restart" lacks "stopping the running node"
expect "same release: still online" has "node already online"

# 5. Opt-out and skills-only: installed SKILL.md identical to the repo's.
install PILOT_SKILLS_ONLY=1 PILOT_MUSE_FRONTMATTER=0
expect "opt-out: rc 0" [ "$RC" = 0 ]
for s in pilotctl pilot-protocol pilot-sandbox; do
  expect "opt-out: $s untouched" cmp -s "$ROOT/skills/$s/SKILL.md" "$H/workspace/skills/$s/SKILL.md"
done

# 6. No proxy in the environment: PILOT_TRANSPORT is not forced.
rm -rf "$H/.pilot/bin" "$H/.pilot/stub-installer.log"
stop_node
install PILOT_NO_START=1
expect "no proxy: rc 0" [ "$RC" = 0 ]
expect "no proxy: PILOT_TRANSPORT not set" grep -q 'TRANSPORT=$' "$H/.pilot/stub-installer.log"
expect "no start: says so" has "Node not started (PILOT_NO_START=1)"

# 7. PILOT_UPGRADE=1 while a daemon started by hand (no pid file) runs: it is
#    found through its socket and stopped, and the new binary comes up.
by_hand() {
  rm -f "$H/.pilot/stub-state"
  env -i PATH="$PATH" HOME="$H" STUB_HELP_PROXY=1 \
    perl -e 'setpgrp(0, 0); exec @ARGV or die' "$H/.pilot/bin/pilot-daemon" -transport=compat -proxy=auto \
    -socket "$H/pilot.sock" >> "$H/.pilot/hand.log" 2>&1 < /dev/null &
  HAND_PID=$!
  disown "$HAND_PID"
  for _ in $(seq 1 50); do
    [ -S "$H/pilot.sock" ] && [ -s "$H/.pilot/stub-state" ] && break
    sleep 0.1
  done
}
by_hand
hand="$HAND_PID"
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 PILOT_UPGRADE=1 STUB_INSTALL_VERSION=v3.0.0
expect "hand-started upgrade: rc 0" [ "$RC" = 0 ]
expect "hand-started upgrade: daemon found and stopped" has "stopped pilot-daemon pid $hand"
expect "hand-started upgrade: restart announced" has "Restarting the node on the new pilot-daemon"
expect "hand-started upgrade: new version running" has "running v3.0.0"
expect "hand-started upgrade: no drift note" lacks "the running daemon is"
expect "hand-started upgrade: old daemon gone" not kill -0 "$hand" 2> /dev/null

# 8. PILOT_UPGRADE=1 with nothing running: no restart claimed.
stop_node
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 PILOT_UPGRADE=1 STUB_INSTALL_VERSION=v4.0.0
expect "upgrade, nothing running: rc 0" [ "$RC" = 0 ]
expect "upgrade, nothing running: says so" has "No node was running"
expect "upgrade, nothing running: no restart claimed" lacks "Restarting the node"

# 9. PILOT_UPGRADE=1 when what answers cannot be stopped: said plainly, and
#    the final message does not claim the new version runs.
stop_node
bash -c 'sleep 120; true' > /dev/null 2>&1 < /dev/null &
bystander=$!
disown "$bystander"
echo "$bystander v4.0.0" > "$H/.pilot/stub-state"
install HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 PILOT_UPGRADE=1 STUB_INSTALL_VERSION=v5.0.0
expect "unstoppable upgrade: rc 0 (a node answers)" [ "$RC" = 0 ]
expect "unstoppable upgrade: warns" has "could not be stopped, so it stays on the old pilot-daemon"
expect "unstoppable upgrade: no restart claimed" lacks "Restarting the node"
expect "unstoppable upgrade: final message says old daemon" has "runs the old pilot-daemon, which could not be stopped"
expect "unstoppable upgrade: bystander untouched" kill -0 "$bystander"
kill "$bystander" 2> /dev/null
rm -f "$H/.pilot/stub-state"

echo "muse/install.sh: $PASSES passed, $FAILS failed"
[ "$FAILS" = 0 ]
