#!/usr/bin/env bash
# Tests for skills/pilot-sandbox/scripts/pilot-up.sh against stub binaries
# (tests/stubs): pid-file safety, the pinned-trust fallback, transport and
# version reporting. No network, no root needed, nothing outside a temp HOME.
#   bash tests/pilot-up.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UP="$ROOT/skills/pilot-sandbox/scripts/pilot-up.sh"
STUBS="$ROOT/tests/stubs"
FP="c1f958f6bcff667cf6a08d5066cc031a9086115a7667835877ca62a3019b3da9"
T="$(mktemp -d)"
BYSTANDERS=()
FAILS=0
PASSES=0
H=""
OUT=""
RC=0

cleanup() {
  local h
  for h in "$T"/h.*; do
    # In its own process group, so a regression that signals the caller's
    # group cannot take the test runner down with it.
    [ -d "$h/.pilot" ] && env -i PATH="$PATH" HOME="$h" \
      perl -e 'setpgrp(0, 0); exec @ARGV or die' bash "$UP" --stop > /dev/null 2>&1
  done
  for h in ${BYSTANDERS[@]+"${BYSTANDERS[@]}"}; do
    pkill -P "$h" 2> /dev/null
    kill "$h" 2> /dev/null
  done
  rm -rf "$T"
}
trap cleanup EXIT

pass() { PASSES=$((PASSES + 1)); }
failed() {
  FAILS=$((FAILS + 1))
  printf 'FAIL: %s\n' "$1"
  printf '%s\n' "$OUT" | sed 's/^/    | /'
}
expect() { # expect NAME CONDITION...
  local name="$1"
  shift
  if "$@"; then pass; else failed "$name"; fi
}
has() { grep -qF -- "$1" <<< "$OUT"; }
lacks() { ! grep -qF -- "$1" <<< "$OUT"; }

# make_stubs DIR VERSION
make_stubs() {
  mkdir -p "$1"
  local b
  for b in pilot-daemon pilotctl; do
    sed "s/^STUB_VERSION=.*/STUB_VERSION=\"$2\"/" "$STUBS/$b" > "$1/$b.new"
    chmod 755 "$1/$b.new"
    mv -f "$1/$b.new" "$1/$b"
  done
}

new_home() {
  H="$(mktemp -d "$T/h.XXXXXX")"
  make_stubs "$H/.pilot/bin" v1.0.0
}

# up [VAR=value...] [-- ARGS] — run pilot-up.sh with a clean environment, in a
# new process group led by a wrapper shell. Sets OUT and RC. The wrapper writes
# "survived" only if nothing killed it, and when WRAP_PID_TO is set it first
# writes its own pid (= the group id, = pilot-up's parent) into those files.
up() {
  local envs=() args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --) shift; args=("$@"); break ;;
      *) envs+=("$1"); shift ;;
    esac
  done
  rm -f "$T/survived" "$T/out"
  # shellcheck disable=SC2016 # expanded by the wrapper shell
  env -i PATH="$PATH" HOME="$H" PILOT_SOCKET="$H/pilot.sock" PILOT_UP_WAIT=8 \
    ${envs[@]+"${envs[@]}"} \
    perl -e 'setpgrp(0, 0); exec @ARGV or die "exec: $!"' \
    bash -c 'run="$1"; shift
             for f in ${WRAP_PID_TO:-}; do echo $$ > "$f"; done
             bash "$0" "$@" > "$run.out" 2>&1; echo $? > "$run.rc"; touch "$run.survived"' \
    "$UP" "$T/run" ${args[@]+"${args[@]}"} < /dev/null
  OUT="$(cat "$T/run.out" 2> /dev/null)"
  RC="$(cat "$T/run.rc" 2> /dev/null || echo killed)"
  SURVIVED=0
  [ -f "$T/run.survived" ] && SURVIVED=1
  rm -f "$T/run.out" "$T/run.rc" "$T/run.survived"
}

alive() { kill -0 "$1" 2> /dev/null; }
not() { ! "$@"; }

echo "=== pilot-up.sh tests ==="

# 1. pilot.pid holding "0" (a failed `pilotctl daemon start`): never signalled.
new_home
printf '0\n' > "$H/.pilot/pilot.pid"
up STUB_HELP_PROXY=1 HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9
expect "pid 0: caller's process group survives" [ "$SURVIVED" = 1 ]
expect "pid 0: node comes up (rc 0)" [ "$RC" = 0 ]
expect "pid 0: stale file reported" has "removed stale $H/.pilot/pilot.pid"
expect "pid 0: native path chosen" has "native path"
expect "pid 0: 'auto-detect' is not -transport=auto" grep -q -- '-transport=compat' "$H/.pilot/stub-args.log"
expect "proxy credentials never printed" lacks "s3cret"
expect "proxy shown redacted" has "proxy: http://***@127.0.0.1:9"
printf '0\n' > "$H/.pilot/pilot.pid"
printf '0\n' > "$H/.pilot/pilot-up.pid"
printf '0\n' > "$H/.pilot/sni_router.pid"
up -- --stop
expect "--stop with pid 0 files: survives" [ "$SURVIVED" = 1 ]
expect "--stop with pid 0 files: rc 0" [ "$RC" = 0 ]
expect "--stop removes pilot.pid" [ ! -e "$H/.pilot/pilot.pid" ]
expect "--stop removes pilot-up.pid" [ ! -e "$H/.pilot/pilot-up.pid" ]
# The daemon started above is still running (pilot.pid was overwritten with
# "0" by hand), so stop it through the pid the stub recorded.
stub_pid=""
read -r stub_pid _ < "$H/.pilot/stub-state" 2> /dev/null
if [ -n "$stub_pid" ]; then kill "$stub_pid" 2> /dev/null; fi

# 2. Our own parent / process group in every pid file: never signalled.
new_home
up STUB_HELP_PROXY=1 "WRAP_PID_TO=$H/.pilot/pilot.pid $H/.pilot/pilot-up.pid $H/.pilot/sni_router.pid"
expect "pgid in pid files: survives" [ "$SURVIVED" = 1 ]
expect "pgid in pid files: not adopted as a respawn loop" lacks "already running"
expect "pgid in pid files: node comes up" [ "$RC" = 0 ]
up -- --stop
up "WRAP_PID_TO=$H/.pilot/pilot.pid $H/.pilot/pilot-up.pid $H/.pilot/sni_router.pid" -- --stop
expect "--stop with pgid in pid files: survives" [ "$SURVIVED" = 1 ]

# 3. Stale pid files naming live bystanders (pid reuse after a VM restart):
#    not adopted, not signalled. One bystander mentions pilot-daemon in its
#    command line (the old substring check would have killed it).
bash -c 'sleep 300; true' > /dev/null 2>&1 < /dev/null &
BYSTANDERS+=($!)
bash -c 'sleep 300; true' pilot-daemon-log-watcher > /dev/null 2>&1 < /dev/null &
BYSTANDERS+=($!)
disown -a
b1="${BYSTANDERS[0]}"
b2="${BYSTANDERS[1]}"
new_home
echo "$b1" > "$H/.pilot/pilot-up.pid"
echo "$b2" > "$H/.pilot/pilot.pid"
echo "$b1" > "$H/.pilot/sni_router.pid"
up STUB_HELP_PROXY=1
expect "stale pids: live bystander not adopted" lacks "already running"
expect "stale pids: node comes up" [ "$RC" = 0 ]
expect "stale pids: bystanders alive after start" alive "$b1"
expect "stale pids: pilot-daemon-looking bystander alive" alive "$b2"
up -- --stop
expect "--stop stops the real loop" has "stopped respawn loop"
echo "$b1" > "$H/.pilot/pilot-up.pid"
echo "$b2" > "$H/.pilot/pilot.pid"
echo "$b1" > "$H/.pilot/sni_router.pid"
up -- --stop
expect "--stop with stale pids: bystanders alive" alive "$b1"
expect "--stop with stale pids: second bystander alive" alive "$b2"
expect "--stop with stale pids: nothing claimed stopped" lacks "stopped"

# 4. Garbage in the pid file.
new_home
printf 'not-a-pid\n' > "$H/.pilot/pilot.pid"
printf -- '-1\n' > "$H/.pilot/pilot-up.pid"
up STUB_HELP_PROXY=1
expect "garbage pids: survives" [ "$SURVIVED" = 1 ]
expect "garbage pids: comes up" [ "$RC" = 0 ]
up -- --stop

# 5. Registry x509 under system trust: automatic retry with the bundled pin.
new_home
up STUB_HELP_PROXY=1 STUB_X509_UNLESS_PINNED=1
expect "x509 fallback: comes up (rc 0)" [ "$RC" = 0 ]
expect "x509 fallback: says so" has "retrying once with -registry-trust=pinned"
expect "x509 fallback: names the fingerprint source" has "(bundled)"
expect "x509 fallback: pinned with the bundled fingerprint" grep -q -- "-registry-trust pinned -registry-fingerprint $FP" "$H/.pilot/stub-args.log"
expect "x509 fallback: reports the trust used" has "registry trust pinned"
up -- --stop

# 6. Explicit PILOT_REGISTRY_TRUST=system: no fallback, a TLS next step.
new_home
up STUB_HELP_PROXY=1 STUB_X509_UNLESS_PINNED=1 PILOT_REGISTRY_TRUST=system
expect "explicit system trust: rc 1" [ "$RC" = 1 ]
expect "explicit system trust: no retry" lacks "retrying once"
expect "explicit system trust: TLS next step" has "next step: TLS trust failed"
up -- --stop

# 7. PILOT_REGISTRY_FINGERPRINT override and validation.
new_home
up STUB_HELP_PROXY=1 PILOT_REGISTRY_TRUST=pinned PILOT_REGISTRY_FINGERPRINT=nothex
expect "bad fingerprint: usage error" [ "$RC" = 2 ]
up STUB_HELP_PROXY=1 PILOT_REGISTRY_TRUST=pinned "PILOT_REGISTRY_FINGERPRINT=$(printf 'ab%.0s' $(seq 1 32))"
expect "fingerprint override used" grep -q -- "-registry-fingerprint $(printf 'ab%.0s' $(seq 1 32))" "$H/.pilot/stub-args.log"
up -- --stop

# 8. -transport=auto when offered; -config when config.json exists; a proxy
#    key in config.json suppresses -proxy=auto on argv.
new_home
printf '{"proxy": "auto", "socket": "/nonexistent.sock"}\n' > "$H/.pilot/config.json"
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1
expect "transport auto: rc 0" [ "$RC" = 0 ]
expect "transport auto: passed" grep -q -- '-transport=auto' "$H/.pilot/stub-args.log"
expect "config passed" grep -qF -- "-config $H/.pilot/config.json" "$H/.pilot/stub-args.log"
expect "config proxy key: no -proxy on argv" not grep -q -- '-proxy' "$H/.pilot/stub-args.log"
expect "PILOT_SOCKET beats config.json" grep -qF -- "-socket $H/pilot.sock" "$H/.pilot/stub-args.log"
up STUB_HELP_PROXY=1 PILOT_UP_TRANSPORT=compat
expect "already online: rc 0" [ "$RC" = 0 ]
expect "already online: running version reported" has "running v1.0.0"

# 9. Binary on disk upgraded, daemon not restarted: say so truthfully.
make_stubs "$H/.pilot/bin" v2.0.0
up STUB_HELP_PROXY=1
expect "version drift: rc 0" [ "$RC" = 0 ]
expect "version drift: still online" has "node already online"
expect "version drift: running version, not the file's" has "running v1.0.0"
expect "version drift: restart hint" has "the running daemon is v1.0.0 but $H/.pilot/bin/pilot-daemon is v2.0.0"
up -- --stop
up STUB_HELP_PROXY=1
expect "after restart: new version running" has "running v2.0.0"
expect "after restart: no drift note" lacks "the running daemon is"
up -- --stop

# 10. Direct path: older daemon, no proxy.
new_home
up
expect "direct path: rc 0" [ "$RC" = 0 ]
expect "direct path: chosen" has "direct path"
up -- --stop

# 11. Older daemon behind a proxy, sni path out of reach: exit 3 with advice
#     that works as root too (the Muse installer, which passes PILOT_ALLOW_ROOT).
new_home
up HTTPS_PROXY=http://u:p@127.0.0.1:9
if [ "$(id -u)" = 0 ] && unshare -m true 2> /dev/null; then
  echo "  (skipping exit-3 checks: root with CAP_SYS_ADMIN here)"
else
  expect "needs root: exit 3" [ "$RC" = 3 ]
  expect "needs root: upgrade advice via the Muse installer" has "muse/install.sh | PILOT_UPGRADE=1 bash"
  expect "needs root: mentions PILOT_ALLOW_ROOT" has "PILOT_ALLOW_ROOT=1"
fi

# 12. Failure output is redacted, even for a password containing '@'.
new_home
up STUB_HELP_PROXY=1 STUB_NEVER_REGISTER=1 PILOT_UP_WAIT=3 \
  'HTTPS_PROXY=http://alice:pa@ss@proxy.example:3128' \
  'STUB_ECHO=dial http://alice:pa@ss@proxy.example:3128 failed'
expect "not registered: rc 1" [ "$RC" = 1 ]
expect "log tail redacted" has "dial http://***@proxy.example:3128 failed"
expect "no password fragment (ss@)" lacks "ss@proxy"
expect "no password fragment (pa@)" lacks "pa@"
expect "daemon.log is owner-only" [ "$(stat -c %a "$H/.pilot/daemon.log" 2> /dev/null || stat -f %Lp "$H/.pilot/daemon.log")" = 600 ]
up -- --stop

# 13. Usage.
up -- --help
expect "--help: rc 0" [ "$RC" = 0 ]
expect "--help: usage text" has "pilot-up.sh --stop"
up PILOT_UP_TRANSPORT=udp
expect "bad PILOT_UP_TRANSPORT: rc 2" [ "$RC" = 2 ]

echo "pilot-up.sh: $PASSES passed, $FAILS failed"
[ "$FAILS" = 0 ]
