#!/usr/bin/env bash
# Tests for skills/pilot-sandbox/scripts/pilot-up.sh against stub binaries
# (tests/stubs): pid-file safety, the pinned-trust fallback, transport choice,
# version reporting, stopping nodes pilot-up did not start, and rotating proxy
# credentials (cmd mode: -proxy-cmd; relay mode: the real egress_relay.py;
# static mode: restarts). No network, no root needed, nothing outside a temp
# HOME: every run gets PILOT_SOCKET inside it, so a real daemon on
# /tmp/pilot.sock is never looked at, and PILOT_RELAY_LISTEN on a random port,
# so a relay on 127.0.0.1:3128 is never touched.
#   bash tests/pilot-up.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UP="$ROOT/skills/pilot-sandbox/scripts/pilot-up.sh"
STUBS="$ROOT/tests/stubs"
FP="c1f958f6bcff667cf6a08d5066cc031a9086115a7667835877ca62a3019b3da9"
T="$(mktemp -d)"
RELAY_PORT=$((40000 + RANDOM % 10000))
RELAY="127.0.0.1:$RELAY_PORT"
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
    [ -d "$h/.pilot" ] && env -i PATH="$PATH" HOME="$h" PILOT_SOCKET="$h/pilot.sock" PILOT_RELAY_LISTEN="$RELAY" \
      perl -e 'setpgrp(0, 0); exec @ARGV or die' bash "$UP" --stop > /dev/null 2>&1
  done
  for h in ${BYSTANDERS[@]+"${BYSTANDERS[@]}"}; do
    pkill -P "$h" 2> /dev/null
    kill "$h" 2> /dev/null
  done
  # Anything started by hand below (stub daemons, routers) runs from $T.
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
  env -i PATH="$PATH" HOME="$H" PILOT_SOCKET="$H/pilot.sock" PILOT_UP_WAIT=8 PILOT_RELAY_LISTEN="$RELAY" \
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

# by_hand [VAR=value...] -- ARGS — start the stub pilot-daemon the way the old
# "by hand" recipes did: no pid file, own process group. Sets HAND_PID.
by_hand() {
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    envs+=("$1")
    shift
  done
  shift
  rm -f "$H/.pilot/stub-state"
  env -i PATH="$PATH" HOME="$H" ${envs[@]+"${envs[@]}"} \
    perl -e 'setpgrp(0, 0); exec @ARGV or die' "$H/.pilot/bin/pilot-daemon" "$@" \
    >> "$H/.pilot/hand.log" 2>&1 < /dev/null &
  HAND_PID=$!
  disown "$HAND_PID"
  local i=0
  while [ ! -s "$H/.pilot/stub-state" ] && [ "$i" -lt 50 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  i=0
  while [ ! -S "$H/pilot.sock" ] && [ "$i" -lt 50 ]; do
    sleep 0.1
    i=$((i + 1))
  done
}
count_lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
last_line() { tail -n 1 "$1" 2> /dev/null; }

echo "=== pilot-up.sh tests ==="

# 1. pilot.pid holding "0" (a failed `pilotctl daemon start`): never signalled.
new_home
printf '0\n' > "$H/.pilot/pilot.pid"
up STUB_HELP_PROXY=1 HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9
expect "pid 0: caller's process group survives" [ "$SURVIVED" = 1 ]
expect "pid 0: node comes up (rc 0)" [ "$RC" = 0 ]
expect "pid 0: stale file reported" has "removed stale $H/.pilot/pilot.pid"
expect "pid 0: native path chosen" has "native path"
expect "pid 0: behind a proxy: -transport=compat" grep -q -- '-transport=compat' "$H/.pilot/stub-args.log"
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
expect "direct path: 'auto-detect' is not -transport=auto" grep -q -- '-transport=compat' "$H/.pilot/stub-args.log"
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
up PILOT_UP_TRANSPORT=quic
expect "bad PILOT_UP_TRANSPORT: rc 2" [ "$RC" = 2 ]

# 14. Transport: compat whenever a proxy is set, even when the daemon offers
#     auto (auto settles on udp when its one check through the proxy fails,
#     and udp never uses the proxy).
new_home
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1 HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9
expect "proxy + auto offered: rc 0" [ "$RC" = 0 ]
expect "proxy + auto offered: -transport=compat" grep -q -- '-transport=compat' "$H/.pilot/stub-args.log"
expect "proxy + auto offered: never -transport=auto" not grep -q -- '-transport=auto' "$H/.pilot/stub-args.log"
expect "proxy + auto offered: says why" has "-transport=compat (proxy in the environment)"
up -- --stop
new_home
mkdir -p "$H/.pilot/targets"
: > "$H/.pilot/targets/muse"
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1
expect "Muse marker, no proxy env: -transport=compat" grep -q -- '-transport=compat' "$H/.pilot/stub-args.log"
expect "Muse marker: says why" has "(Muse host"
up -- --stop
new_home
printf '{"transport": "auto"}\n' > "$H/.pilot/config.json"
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1 HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9
expect "config auto + proxy: -transport=compat on argv" grep -q -- '-transport=compat' "$H/.pilot/stub-args.log"
expect "config auto + proxy: says it overrides" has "note: config.json sets transport auto; using compat"
up -- --stop
new_home
printf '{"proxy": "http://cfg:pw@127.0.0.1:9"}\n' > "$H/.pilot/config.json"
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1
expect "proxy in config.json: -transport=compat" grep -q -- '-transport=compat' "$H/.pilot/stub-args.log"
up -- --stop
new_home
printf '{"transport": "compat"}\n' > "$H/.pilot/config.json"
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1
expect "config transport, no proxy: rc 0" [ "$RC" = 0 ]
expect "config transport, no proxy: not overridden on argv" not grep -q -- '-transport' "$H/.pilot/stub-args.log"
expect "config transport, no proxy: says so" has "transport from config.json"
up -- --stop
new_home
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1 HTTPS_PROXY=http://alice:s3cret@127.0.0.1:9 PILOT_UP_TRANSPORT=auto
expect "PILOT_UP_TRANSPORT=auto wins" grep -q -- '-transport=auto' "$H/.pilot/stub-args.log"
up -- --stop
new_home
up STUB_HELP_PROXY=1 STUB_TRANSPORT_AUTO=1 STUB_NEVER_REGISTER=1 PILOT_UP_WAIT=3 \
  'STUB_ECHO=msg="transport auto-selected" transport=udp reason="compat beacon unreachable (proxy CONNECT beacon.pilotprotocol.network:443: 407 Proxy Authentication Required)"'
expect "auto settled on udp: rc 1" [ "$RC" = 1 ]
expect "auto settled on udp: next step forces compat" has "next step: -transport=auto settled on udp"
up -- --stop

# 15. A daemon pilot-up did not start (by hand, no pid file): --stop finds it
#     through its socket, the drift note's restart command works, and a
#     daemon that cannot be stopped is reported with exit 1.
new_home
by_hand STUB_HELP_PROXY=1 -- -transport=compat -proxy=auto -socket "$H/pilot.sock"
hand="$HAND_PID"
up STUB_HELP_PROXY=1
expect "by hand: already online" has "node already online"
up -- --stop
expect "by hand --stop: rc 0" [ "$RC" = 0 ]
expect "by hand --stop: found on the socket" has "stopped pilot-daemon pid $hand (it answered on $H/pilot.sock; not started by pilot-up)"
expect "by hand --stop: daemon gone" not alive "$hand"
up -- --stop
expect "nothing running --stop: rc 0" [ "$RC" = 0 ]
expect "nothing running --stop: says so" has "nothing to stop"
by_hand STUB_HELP_PROXY=1 -- -transport=compat -socket "$H/pilot.sock"
hand="$HAND_PID"
make_stubs "$H/.pilot/bin" v2.0.0
up STUB_HELP_PROXY=1
expect "by hand + upgraded binary: drift note" has "the running daemon is v1.0.0"
up -- --stop
expect "drift advice (--stop) stops the hand-started daemon" not alive "$hand"
up STUB_HELP_PROXY=1
expect "drift advice (pilot-up) runs the new binary" has "running v2.0.0"
up -- --stop
# No socket owner to find (no listener): pilotctl daemon stop is asked.
by_hand STUB_HELP_PROXY=1 -- -transport=compat
hand="$HAND_PID"
up STUB_CTL_DISCOVER=1 -- --stop
expect "pilotctl fallback: rc 0" [ "$RC" = 0 ]
expect "pilotctl fallback: says so" has "(pilotctl daemon stop; not started by pilot-up)"
expect "pilotctl fallback: daemon gone" not alive "$hand"
# Something answers that is not pilot-daemon and pilotctl cannot stop it.
bash -c 'sleep 300; true' > /dev/null 2>&1 < /dev/null &
BYSTANDERS+=($!)
disown -a
b3="$!"
echo "$b3 v1.0.0" > "$H/.pilot/stub-state"
up -- --stop
expect "unstoppable: rc 1" [ "$RC" = 1 ]
expect "unstoppable: says so" has "could not be stopped"
expect "unstoppable: the non-daemon owner is left alone" alive "$b3"
rm -f "$H/.pilot/stub-state"

# 16. An SNI router started by hand (no pid file) holding the router port is
#     stopped by --stop (and would otherwise make the sni path fail with
#     "Address already in use").
if command -v python3 > /dev/null 2>&1 && { [ -r /proc/net/tcp ] || command -v lsof > /dev/null 2>&1; }; then
  new_home
  port=$((20000 + RANDOM % 20000))
  env -i PATH="$PATH" HOME="$H" HTTPS_PROXY=http://u:p@127.0.0.1:9 PILOT_SNI_LISTEN="127.0.0.1:$port" \
    perl -e 'setpgrp(0, 0); exec @ARGV or die' python3 "$ROOT/skills/pilot-sandbox/scripts/sni_router.py" \
    >> "$H/.pilot/hand-router.log" 2>&1 < /dev/null &
  router="$!"
  disown "$router"
  for _ in $(seq 1 50); do
    grep -q 'listening' "$H/.pilot/hand-router.log" 2> /dev/null && break
    sleep 0.1
  done
  up "PILOT_SNI_LISTEN=127.0.0.1:$port" -- --stop
  expect "router by hand --stop: rc 0" [ "$RC" = 0 ]
  expect "router by hand --stop: found" has "stopped SNI router pid $router (listening on port $port; not started by pilot-up)"
  expect "router by hand --stop: gone" not alive "$router"
else
  echo "  (skipping hand-started router check: needs python3 and /proc or lsof)"
fi

# 17. Static mode (no -proxy-cmd, no relay): proxy credentials rotate (Meta
#     Muse), and a rerun with different settings restarts what holds the old
#     ones instead of reusing it.
new_home
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static STUB_NEVER_REGISTER=1 PILOT_UP_WAIT=2 HTTPS_PROXY=http://muse:oldpw@127.0.0.1:9
expect "rotation: first run not registered" [ "$RC" = 1 ]
expect "rotation: settings recorded" [ -s "$H/.pilot/pilot-up.proxy" ]
expect "rotation: record is owner-only" [ "$(stat -c %a "$H/.pilot/pilot-up.proxy" 2> /dev/null || stat -f %Lp "$H/.pilot/pilot-up.proxy")" = 600 ]
expect "rotation: record holds no credentials" not grep -q 'oldpw' "$H/.pilot/pilot-up.proxy"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static STUB_NEVER_REGISTER=1 PILOT_UP_WAIT=2 HTTPS_PROXY=http://muse:oldpw@127.0.0.1:9
expect "rotation: same settings: loop adopted" has "respawn loop already running"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:newpw@127.0.0.1:9
expect "rotation: new settings: rc 0" [ "$RC" = 0 ]
expect "rotation: new settings: loop restarted" has "restarting respawn loop pid"
expect "rotation: new settings: not adopted" lacks "waiting for it instead"
expect "rotation: daemon started with the new proxy" [ "$(last_line "$H/.pilot/stub-env.log")" = "http://muse:newpw@127.0.0.1:9" ]
starts="$(count_lines "$H/.pilot/stub-args.log")"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:thirdpw@127.0.0.1:9
expect "rotation, online, no 407: left running" has "node already online"
expect "rotation, online, no 407: note" has "differs from the one the node started with"
expect "rotation, online, no 407: no restart" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
echo 'level=WARN msg="registry dial failed" error="proxy CONNECT registry.pilotprotocol.network:443: 407 Proxy Authentication Required"' >> "$H/.pilot/daemon.log"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:thirdpw@127.0.0.1:9
expect "rotation, online, 407: rc 0" [ "$RC" = 0 ]
expect "rotation, online, 407: restarts" has "restarting the node with the current ones"
expect "rotation, online, 407: back online" has "node online via the native path"
expect "rotation, online, 407: new proxy in use" [ "$(last_line "$H/.pilot/stub-env.log")" = "http://muse:thirdpw@127.0.0.1:9" ]
starts="$(count_lines "$H/.pilot/stub-args.log")"
echo 'level=WARN msg="registry dial failed" error="proxy CONNECT registry.pilotprotocol.network:443: 407 Proxy Authentication Required"' >> "$H/.pilot/daemon.log"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:thirdpw@127.0.0.1:9
expect "407 with the current credentials: warns" has "the node already uses this shell's HTTPS_PROXY"
expect "407 with the current credentials: no pointless restart" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
expect "rotation: credentials never printed" lacks "pw@"
up -- --stop
expect "--stop removes the settings record" [ ! -e "$H/.pilot/pilot-up.proxy" ]
new_home
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static STUB_NEVER_REGISTER=1 PILOT_UP_WAIT=3 HTTPS_PROXY=http://muse:pw@127.0.0.1:9 \
  'STUB_ECHO=proxy CONNECT registry.pilotprotocol.network:443: 407 Proxy Authentication Required'
expect "407 next step: rc 1" [ "$RC" = 1 ]
expect "407 next step: fresh shell (rotation)" has "Rerun from a new shell"
up -- --stop
new_home
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static STUB_NEVER_REGISTER=1 PILOT_UP_WAIT=3 HTTPS_PROXY=http://muse:pw@127.0.0.1:9 \
  'STUB_ECHO=dial registry TLS: proxy CONNECT registry.pilotprotocol.network:443: 502 Bad Gateway'
expect "502 next step: upstream, not the allowlist" has "could not reach the Pilot host (502/503/504)"
up -- --stop

# 18. What counts as the proxy rejecting credentials: its signatures only,
#     never a bare 407 (slog timestamps are stamped to the millisecond, so
#     about one daemon line in a thousand carries ".407").
# sourced FUNCTION [ARGS] — run a pilot-up.sh function in a subshell (the file
# runs main only when executed), with a throwaway HOME.
sourced() {
  (
    HOME="$T/unit-home"
    # shellcheck source=skills/pilot-sandbox/scripts/pilot-up.sh
    source "$UP" > /dev/null 2>&1 || exit 99
    set +e
    "$@"
  )
}
rejects() { printf '%s\n' "$1" | sourced auth_rejected; }
while IFS= read -r line; do
  [ -n "$line" ] || continue
  OUT="$line"
  expect "not a proxy 407: $line" not rejects "$line"
done << 'LINES'
time=2026-09-24T02:27:46.407+03:00 level=INFO msg="compat mode tunnel up" peers=3
time=2026-09-23T23:36:28.407Z level=INFO msg="registry heartbeat" rtt=407ms
time=2026-09-23T23:36:28.195Z level=INFO msg="beacon reconnect" backoff=1.407s bytes=407
time=2026-09-23T23:36:28.195Z level=INFO msg="peer up" addr=0:0000.0000.A407 port=407
pilot-up: daemon exited (rc=1) after 407s; restarting in 2s
time=2026-09-23T23:36:28.195Z level=WARN msg="dial failed" error="proxy CONNECT beacon.pilotprotocol.network:443: 403 Forbidden"
proxy refused CONNECT registry.pilotprotocol.network:443: b'HTTP/1.1 502 Bad Gateway'
LINES
while IFS= read -r line; do
  [ -n "$line" ] || continue
  OUT="$line"
  expect "proxy 407: $line" rejects "$line"
done << 'LINES'
time=2026-09-23T23:36:28.195Z level=WARN msg="registry dial failed" error="proxy CONNECT registry.pilotprotocol.network:443: 407 Proxy Authentication Required"
proxy refused CONNECT registry.pilotprotocol.network:443: b'HTTP/1.1 407 Proxy Authentication Required'
proxy refused CONNECT beacon.pilotprotocol.network:443: b'HTTP/1.0 407 authenticationrequired'
time=2026-09-23T23:36:28.195Z level=WARN msg="beacon dial failed" err="proxy authentication required"
time=2026-09-23T23:36:28.195Z level=WARN msg="beacon dial failed" err="malformed HTTP status code \"x\""
time=2026-09-23T23:36:28.195Z level=WARN msg="registry dial failed" error="proxy CONNECT: 407 Proxy Authentication Required"
LINES
every_ms="$(for i in $(seq 0 999); do printf 'time=2026-09-24T02:27:46.%03dZ level=INFO msg=tick rtt=%dms bytes=%d\n' "$i" "$i" "$i"; done)"
OUT="(1000 slog lines, every millisecond stamp)"
expect "no false 407 in a thousand slog lines" not rejects "$every_ms"

# 19. A node pilot-up's respawn loop does not run, or a 407 older than the
#     loop's last start, never restarts or stops anything; neither do slog
#     lines stamped .407.
SLOG='time=2026-09-24T02:27:46.407+03:00 level=INFO msg="compat mode tunnel up" peers=3 rtt=407ms'
REAL407='time=2026-09-24T02:27:47.001+03:00 level=WARN msg="registry dial failed" error="proxy CONNECT registry.pilotprotocol.network:443: 407 Proxy Authentication Required"'
new_home
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:credA@127.0.0.1:9
expect ".407 stamp: first start online" [ "$RC" = 0 ]
{
  echo "$SLOG"
  echo 'pilot-up: daemon exited (rc=1) after 407s; restarting in 2s'
} >> "$H/.pilot/daemon.log"
starts="$(count_lines "$H/.pilot/stub-args.log")"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:credB@127.0.0.1:9
expect ".407 stamp, rotated shell: rc 0" [ "$RC" = 0 ]
expect ".407 stamp, rotated shell: left running" has "node already online"
expect ".407 stamp, rotated shell: no restart" lacks "restarting the node"
expect ".407 stamp, rotated shell: no new daemon" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
expect ".407 stamp, rotated shell: note" has "differs from the one the node started with"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:credA@127.0.0.1:9
expect ".407 stamp, same shell: no false warning" lacks "warning"
expect ".407 stamp, same shell: no restart" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
# A real 407 logged by an earlier run, before the loop's latest start.
echo "$REAL407" >> "$H/.pilot/daemon.log"
up -- --stop
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:credA@127.0.0.1:9
expect "407 before the last start: online" [ "$RC" = 0 ]
starts="$(count_lines "$H/.pilot/stub-args.log")"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:credB@127.0.0.1:9
expect "407 before the last start: no restart" lacks "restarting the node"
expect "407 before the last start: no new daemon" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
# Another pilot-daemon took over the socket after pilot-up's started: the log
# after the marker is not that node's, so nothing is restarted or stopped.
echo "$REAL407" >> "$H/.pilot/daemon.log"
by_hand STUB_HELP_PROXY=1 -- -transport=compat -socket "$H/pilot.sock"
hand="$HAND_PID"
sleep 0.5
starts="$(count_lines "$H/.pilot/stub-args.log")"
up STUB_HELP_PROXY=1 PILOT_UP_CREDS=static HTTPS_PROXY=http://muse:credB@127.0.0.1:9
expect "socket taken over: online" has "node already online"
expect "socket taken over: no restart" lacks "restarting the node"
expect "socket taken over: other daemon untouched" alive "$hand"
expect "socket taken over: no new daemon" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
up -- --stop
expect "socket taken over: --stop stops both" not alive "$hand"
# A node started outside pilot-up (by hand, a service) that logs to
# ~/.pilot/daemon.log, even with a real 407 there and an old pilot-up marker
# before it: a note, never a stop (pilotctl daemon stop would boot a launchd
# agent out for good).
new_home
{
  echo 'pilot-up: 2026-09-20T10:00:00Z starting /old/pilot-daemon -transport=compat'
  echo "$SLOG"
  echo "$REAL407"
} >> "$H/.pilot/daemon.log"
by_hand STUB_HELP_PROXY=1 -- -transport=compat -proxy=auto -socket "$H/pilot.sock"
hand="$HAND_PID"
starts="$(count_lines "$H/.pilot/stub-args.log")"
up STUB_HELP_PROXY=1 STUB_CTL_DISCOVER=1 HTTPS_PROXY=http://corp:pw@proxy.corp:8080
expect "not pilot-up's node: rc 0" [ "$RC" = 0 ]
expect "not pilot-up's node: left running" has "node already online"
expect "not pilot-up's node: not restarted" lacks "restarting"
expect "not pilot-up's node: not stopped" lacks "stopped"
expect "not pilot-up's node: still alive" alive "$hand"
expect "not pilot-up's node: no new daemon" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
expect "not pilot-up's node: note says so" has "this node was not started by pilot-up"
up -- --stop

# 20. A stale pilot.pid naming another project's run-daemon.sh is not ours:
#     removed, never signalled. This skill's run-daemon.sh (by absolute path,
#     or relative to the process's working directory on Linux) still is.
mkdir -p "$T/otherapp"
printf '#!/bin/bash\nwhile :; do sleep 1; done\n' > "$T/otherapp/run-daemon.sh"
bash "$T/otherapp/run-daemon.sh" > /dev/null 2>&1 < /dev/null &
BYSTANDERS+=($!)
b4="$!"
(cd "$T/otherapp" && exec bash ./run-daemon.sh) > /dev/null 2>&1 < /dev/null &
BYSTANDERS+=($!)
b5="$!"
disown -a
sleep 0.3
OUT="bystanders $b4 $b5"
expect "other run-daemon.sh (absolute) is not a daemon" not sourced is_daemon "$b4"
expect "other run-daemon.sh (relative) is not a daemon" not sourced is_daemon "$b5"
OURS="$ROOT/skills/pilot-sandbox/scripts/run-daemon.sh"
PERL="$(command -v perl)"
# perl with argv "bash -e 'sleep 300' <path>": looks like bash running <path>.
# shellcheck disable=SC2016 # $ARGV is perl's
"$PERL" -e 'exec {$ARGV[0]} "bash", "-e", "sleep 300", $ARGV[1] or die' "$PERL" "$OURS" > /dev/null 2>&1 < /dev/null &
fake_abs="$!"
# shellcheck disable=SC2016 # $ARGV is perl's
(cd "$ROOT/skills/pilot-sandbox" && exec "$PERL" -e 'exec {$ARGV[0]} "bash", "-e", "sleep 300", "./scripts/run-daemon.sh" or die' "$PERL") > /dev/null 2>&1 < /dev/null &
fake_rel="$!"
BYSTANDERS+=("$fake_abs" "$fake_rel")
disown -a
sleep 0.3
OUT="$(tr '\0' ' ' 2> /dev/null < "/proc/$fake_abs/cmdline" || ps -ww -o command= -p "$fake_abs")"
expect "this skill's run-daemon.sh (absolute) is ours" sourced is_daemon "$fake_abs"
if [ -d "/proc/$fake_rel/cwd" ]; then
  expect "this skill's run-daemon.sh (relative, /proc cwd) is ours" sourced is_daemon "$fake_rel"
else
  expect "relative run-daemon.sh without /proc: not trusted" not sourced is_daemon "$fake_rel"
fi
new_home
echo "$b4" > "$H/.pilot/pilot.pid"
up STUB_HELP_PROXY=1
expect "other run-daemon.sh in pilot.pid: node comes up" [ "$RC" = 0 ]
expect "other run-daemon.sh in pilot.pid: removed as stale" has "removed stale $H/.pilot/pilot.pid"
expect "other run-daemon.sh in pilot.pid: not stopped" lacks "stopping unregistered"
expect "other run-daemon.sh in pilot.pid: alive after start" alive "$b4"
up -- --stop
echo "$b5" > "$H/.pilot/pilot.pid"
up -- --stop
expect "other run-daemon.sh in pilot.pid: alive after --stop" alive "$b4"
expect "relative other run-daemon.sh in pilot.pid: alive after --stop" alive "$b5"
new_home
echo "$fake_abs" > "$H/.pilot/pilot.pid"
up STUB_HELP_PROXY=1
expect "our run-daemon.sh in pilot.pid: stopped as a leftover daemon" has "stopping unregistered pilot-daemon pid $fake_abs"
expect "our run-daemon.sh in pilot.pid: gone" not alive "$fake_abs"
expect "our run-daemon.sh in pilot.pid: node comes up" [ "$RC" = 0 ]
up -- --stop

# 21. cmd mode: a pilot-daemon with -proxy-cmd re-reads rotated credentials
#     itself. pilot-up passes the sandbox default unless PILOT_PROXY_CMD or
#     config.json "proxy_cmd" sets one, starts no relay, and a rotation (even
#     with 407s logged) restarts nothing. The respawn loop re-reads the proxy
#     before every start.
new_home
up STUB_HELP_PROXY=1 STUB_HELP_PROXY_CMD=1 HTTPS_PROXY=http://muse:credA@127.0.0.1:9
expect "cmd: rc 0" [ "$RC" = 0 ]
expect "cmd: says so" has "proxy credentials: cmd (pilot-daemon has -proxy-cmd)"
expect "cmd: -proxy-cmd with the sandbox default" grep -qF -- "-proxy-cmd bash -c 'printf %s \"\${https_proxy:-\$HTTPS_PROXY}\"'" "$H/.pilot/stub-args.log"
expect "cmd: no relay" [ ! -e "$H/.pilot/egress_relay.pid" ]
expect "cmd: reported" has "credentials re-read by pilot-daemon (-proxy-cmd)"
expect "cmd: credentials never printed" lacks "credA"
starts="$(count_lines "$H/.pilot/stub-args.log")"
echo "$REAL407" >> "$H/.pilot/daemon.log"
up STUB_HELP_PROXY=1 STUB_HELP_PROXY_CMD=1 HTTPS_PROXY=http://muse:credB@127.0.0.1:9
expect "cmd, rotated + 407: left running" has "node already online"
expect "cmd, rotated + 407: no restart" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
expect "cmd, rotated: no note" lacks "note:"
expect "cmd, rotated: no warning" lacks "warning"
up -- --stop
new_home
printf 'http://muse:credB@127.0.0.1:9\n' > "$H/.pilot/current-proxy"
up STUB_HELP_PROXY=1 STUB_HELP_PROXY_CMD=1 HTTPS_PROXY=http://muse:credA@127.0.0.1:9 "PILOT_PROXY_CMD=cat $H/.pilot/current-proxy"
expect "PILOT_PROXY_CMD: rc 0" [ "$RC" = 0 ]
expect "PILOT_PROXY_CMD: left to the daemon (no -proxy-cmd on argv)" not grep -q -- '-proxy-cmd' "$H/.pilot/stub-args.log"
expect "respawn loop re-reads the proxy for the first start" [ "$(last_line "$H/.pilot/stub-env.log")" = "http://muse:credB@127.0.0.1:9" ]
printf 'http://muse:credC@127.0.0.1:9\n' > "$H/.pilot/current-proxy"
stub_pid=""
read -r stub_pid _ < "$H/.pilot/stub-state" 2> /dev/null
kill -KILL "$stub_pid" 2> /dev/null
for _ in $(seq 1 60); do
  [ "$(count_lines "$H/.pilot/stub-env.log")" -ge 2 ] && break
  sleep 0.2
done
OUT="$(cat "$H/.pilot/daemon.log")"
expect "respawn after a crash re-reads the rotated proxy" [ "$(last_line "$H/.pilot/stub-env.log")" = "http://muse:credC@127.0.0.1:9" ]
expect "respawn: daemon.log says so" has "proxy credentials re-read from a fresh shell"
expect "respawn: daemon.log holds no credentials" lacks "muse:cred"
up -- --stop
new_home
cat > "$H/.pilot/config.json" << 'JSON'
{"transport": "compat", "proxy_cmd": "bash -c 'printf %s \"${https_proxy:-$HTTPS_PROXY}\"'"}
JSON
up STUB_HELP_PROXY=1 STUB_HELP_PROXY_CMD=1 HTTPS_PROXY=http://muse:credA@127.0.0.1:9
expect "config proxy_cmd: cmd mode" has "proxy credentials: cmd"
expect "config proxy_cmd: left to the daemon" not grep -q -- '-proxy-cmd' "$H/.pilot/stub-args.log"
up -- --stop
new_home
up STUB_HELP_PROXY=1 STUB_HELP_PROXY_CMD=1 HTTPS_PROXY=http://muse:credA@127.0.0.1:9 PILOT_PROXY=http://muse:credA@127.0.0.1:9
expect "explicit PILOT_PROXY URL: static" has "proxy credentials: static (PILOT_PROXY or config.json names the proxy URL)"
expect "explicit PILOT_PROXY URL: no -proxy-cmd" not grep -q -- '-proxy-cmd' "$H/.pilot/stub-args.log"
up -- --stop
new_home
up STUB_HELP_PROXY=1 STUB_HELP_PROXY_CMD=1
expect "cmd-capable daemon, no proxy: no credential mode" lacks "proxy credentials:"
expect "no proxy: no -proxy-cmd" not grep -q -- '-proxy-cmd' "$H/.pilot/stub-args.log"
up -- --stop
up PILOT_UP_CREDS=bogus
expect "bad PILOT_UP_CREDS: rc 2" [ "$RC" = 2 ]
up STUB_HELP_PROXY=1 HTTPS_PROXY=http://muse:credA@127.0.0.1:9 PILOT_UP_CREDS=cmd
expect "PILOT_UP_CREDS=cmd without -proxy-cmd: rc 2" [ "$RC" = 2 ]
expect "PILOT_UP_CREDS=cmd without -proxy-cmd: says why" has "PILOT_UP_CREDS=cmd needs"

# 22. relay mode: a pilot-daemon without -proxy-cmd gets the egress relay
#     (the real egress_relay.py) as its proxy, with no credentials in its
#     environment. A rotation restarts nothing, a relay that died is started
#     again on the next run without touching the daemon, --stop stops it, and
#     a relay started by hand is used but never stopped.
if command -v python3 > /dev/null 2>&1 && { [ -r /proc/net/tcp ] || command -v lsof > /dev/null 2>&1; }; then
  RELAY_ENV=(STUB_HELP_PROXY=1 NO_PROXY=internal.example)
  new_home
  up "${RELAY_ENV[@]}" HTTPS_PROXY=http://muse:credA@127.0.0.1:9 ALL_PROXY=http://muse:credA@127.0.0.1:9
  relay_pid="$(cat "$H/.pilot/egress_relay.pid" 2> /dev/null)"
  expect "relay: rc 0" [ "$RC" = 0 ]
  expect "relay: says so" has "proxy credentials: relay (pilot-daemon cannot re-read them itself)"
  expect "relay: started on PILOT_RELAY_LISTEN" has "egress relay pid $relay_pid on $RELAY"
  expect "relay: running" alive "$relay_pid"
  expect "relay: the daemon's proxy is the relay" [ "$(last_line "$H/.pilot/stub-env.log")" = "http://$RELAY" ]
  expect "relay: https_proxy and HTTP_PROXY too, ALL_PROXY dropped, loopback in NO_PROXY" \
    [ "$(last_line "$H/.pilot/stub-env2.log")" = "https_proxy=http://$RELAY HTTP_PROXY=http://$RELAY ALL_PROXY= NO_PROXY=internal.example,localhost,127.0.0.1" ]
  expect "relay: no credentials in the daemon's environment" not grep -q credA "$H/.pilot/stub-env.log" "$H/.pilot/stub-env2.log"
  expect "relay: no -proxy-cmd" not grep -q -- '-proxy-cmd' "$H/.pilot/stub-args.log"
  expect "relay: log is owner-only" [ "$(stat -c %a "$H/.pilot/egress_relay.log" 2> /dev/null || stat -f %Lp "$H/.pilot/egress_relay.log")" = 600 ]
  expect "relay: reported" has "stamped fresh on every connection by the egress relay http://$RELAY"
  expect "relay: credentials never printed" lacks "credA"
  starts="$(count_lines "$H/.pilot/stub-args.log")"
  echo "$REAL407" >> "$H/.pilot/daemon.log"
  up "${RELAY_ENV[@]}" HTTPS_PROXY=http://muse:credB@127.0.0.1:9
  expect "relay, rotated + 407: left running" has "node already online"
  expect "relay, rotated: no restart" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
  expect "relay, rotated: relay kept" alive "$relay_pid"
  expect "relay, rotated: no note" lacks "note:"
  kill "$relay_pid" 2> /dev/null
  for _ in $(seq 1 25); do alive "$relay_pid" || break; sleep 0.2; done
  up "${RELAY_ENV[@]}" HTTPS_PROXY=http://muse:credC@127.0.0.1:9
  new_relay="$(cat "$H/.pilot/egress_relay.pid" 2> /dev/null)"
  expect "relay died: rc 0" [ "$RC" = 0 ]
  expect "relay died: noticed" has "the egress relay this node uses is not running"
  expect "relay died: started again" alive "$new_relay"
  expect "relay died: daemon not restarted" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
  # The proxy rejected even the credentials the relay re-read (its fresh
  # shells see stale ones): the next run restarts it from its own shell.
  echo "[00:00:00] rejected after re-reading the credentials: the proxy URL the credential command prints does not work" >> "$H/.pilot/egress_relay.log"
  up "${RELAY_ENV[@]}" HTTPS_PROXY=http://muse:credD@127.0.0.1:9
  expect "relay rejected re-read credentials: restarted" has "restarting the egress relay (pid $new_relay): the proxy rejected the credentials it re-read"
  new_relay2="$(cat "$H/.pilot/egress_relay.pid" 2> /dev/null)"
  expect "relay rejected: the new relay runs" alive "$new_relay2"
  expect "relay rejected: the old one is gone" not alive "$new_relay"
  expect "relay rejected: daemon not restarted" [ "$(count_lines "$H/.pilot/stub-args.log")" = "$starts" ]
  up "${RELAY_ENV[@]}" HTTPS_PROXY=http://muse:credD@127.0.0.1:9
  expect "relay rejected, next run: the fresh relay is kept" lacks "restarting the egress relay"
  new_relay="$new_relay2"
  up -- --stop
  expect "relay --stop: says so" has "stopped egress relay (pid $new_relay)"
  expect "relay --stop: gone" not alive "$new_relay"
  expect "relay --stop: pid file removed" [ ! -e "$H/.pilot/egress_relay.pid" ]
  # This shell's HTTPS_PROXY is the relay's own address and nothing listens:
  # a relay started from here could not learn the real proxy.
  new_home
  up "${RELAY_ENV[@]}" "HTTPS_PROXY=http://$RELAY"
  expect "shell proxy is the (dead) relay: rc 1" [ "$RC" = 1 ]
  expect "shell proxy is the (dead) relay: says so" has "this shell's HTTPS_PROXY is the egress relay's address"
  expect "shell proxy is the (dead) relay: no daemon started" [ ! -e "$H/.pilot/stub-args.log" ]
  # Something else holds the relay port.
  python3 -c 'import socket, sys, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(5); time.sleep(300)' "$RELAY_PORT" > /dev/null 2>&1 < /dev/null &
  squatter="$!"
  BYSTANDERS+=("$squatter")
  disown "$squatter"
  for _ in $(seq 1 50); do bash -c 'exec 3<> "/dev/tcp/127.0.0.1/$0"' "$RELAY_PORT" 2> /dev/null && break; sleep 0.1; done
  new_home
  up "${RELAY_ENV[@]}" HTTPS_PROXY=http://muse:credA@127.0.0.1:9
  expect "relay port taken: rc 1" [ "$RC" = 1 ]
  expect "relay port taken: says so" has "is taken by a process that is not egress_relay.py"
  expect "relay port taken: the other process is left alone" alive "$squatter"
  kill "$squatter" 2> /dev/null
  for _ in $(seq 1 25); do alive "$squatter" || break; sleep 0.2; done
  # A relay started by hand (the manual recipe) on the relay port.
  new_home
  env -i PATH="$PATH" HOME="$H" HTTPS_PROXY=http://muse:credA@127.0.0.1:9 RELAY_LISTEN="$RELAY" RELAY_LOG="$H/hand-relay.log" \
    perl -e 'setpgrp(0, 0); exec @ARGV or die' python3 "$ROOT/skills/pilot-sandbox/scripts/egress_relay.py" \
    > /dev/null 2>&1 < /dev/null &
  hand_relay="$!"
  BYSTANDERS+=("$hand_relay")
  disown "$hand_relay"
  for _ in $(seq 1 50); do grep -q 'listening' "$H/hand-relay.log" 2> /dev/null && break; sleep 0.1; done
  up "${RELAY_ENV[@]}" HTTPS_PROXY=http://muse:credA@127.0.0.1:9
  expect "hand-started relay: node up" [ "$RC" = 0 ]
  expect "hand-started relay: used" has "using the egress relay already listening on $RELAY (pid $hand_relay"
  expect "hand-started relay: no second relay" [ ! -e "$H/.pilot/egress_relay.pid" ]
  up -- --stop
  expect "hand-started relay: --stop leaves it running" alive "$hand_relay"
  kill "$hand_relay" 2> /dev/null
else
  echo "  (skipping relay-mode checks: needs python3 and /proc or lsof)"
fi

# 23. sni path in relay mode: the SNI router's proxy is the egress relay, even
#     when every bash re-exports the real, rotating proxy (BASH_ENV here, a
#     fresh shell in Muse), because the relay's address is set at the last
#     exec. (The rest of the sni path needs root and unshare.)
if command -v python3 > /dev/null 2>&1; then
  port=$((20000 + RANDOM % 20000))
  rm -rf "$T/unit-home"
  mkdir -p "$T/unit-home/.pilot"
  printf 'export HTTPS_PROXY=http://muse:realpw@127.0.0.1:9 https_proxy=http://muse:realpw@127.0.0.1:9\n' > "$T/bash_env"
  OUT="$(PILOT_SNI_LISTEN="127.0.0.1:$port" PILOT_RELAY_LISTEN="$RELAY" BASH_ENV="$T/bash_env" \
    HTTPS_PROXY=http://muse:realpw@127.0.0.1:9 sourced eval 'CRED_MODE=relay; ensure_router' 2>&1)"
  for _ in $(seq 1 30); do grep -q 'listening' "$T/unit-home/.pilot/sni_router.log" 2> /dev/null && break; sleep 0.1; done
  OUT="$OUT
$(cat "$T/unit-home/.pilot/sni_router.log" 2> /dev/null)"
  expect "sni relay mode: router started" has "SNI router pid"
  expect "sni relay mode: router's proxy is the relay" has "via proxy http://$RELAY"
  expect "sni relay mode: not the real proxy" lacks "127.0.0.1:9"
  OUT="$(PILOT_SNI_LISTEN="127.0.0.1:$port" sourced stop_router 2>&1)"
  expect "sni relay mode: router stopped" has "stopped SNI router"
else
  echo "  (skipping sni relay-mode router check: needs python3)"
fi

echo "pilot-up.sh: $PASSES passed, $FAILS failed"
[ "$FAILS" = 0 ]
