#!/usr/bin/env bash
# pilot-up.sh — bring this sandbox's Pilot node online, or confirm that it
# already is. Idempotent: rerun it after every VM restart (Meta Muse has no
# systemd, so nothing brings the daemon back on its own).
#
#   bash pilot-up.sh           start the node (or adopt a running one) and wait
#   bash pilot-up.sh --stop    stop the daemon, its respawn loop and the SNI router
#
# Launch paths, tried in this order (force one with PILOT_UP_MODE):
#   native  pilot-daemon has the -proxy flag: run it with -proxy=auto and
#           -transport=auto (-transport=compat when its -h does not offer
#           auto). No root. The daemon asks the proxy in HTTPS_PROXY to
#           CONNECT by hostname, so the poisoned local DNS never matters.
#   direct  older pilot-daemon and no proxy in the environment: plain compat
#           mode, TCP/443 straight out.
#   sni     older pilot-daemon behind a proxy: sni_router.py plus
#           `unshare -m run-daemon.sh`. Needs root with CAP_SYS_ADMIN; without
#           it this script prints what to do instead and exits 3.
# Registry TLS starts with system trust. If daemon.log then shows an x509 error
# for the registry, the daemon is restarted once with -registry-trust=pinned
# and the bundled fingerprint (the settings the first Muse node registered
# with). On Linux with no CA bundle where Go looks for one, SSL_CERT_FILE is
# pointed at a bundle found elsewhere on the box, because the beacon (WSS)
# cannot be pinned.
# The daemon runs directly, not through `pilotctl daemon start` (released
# pilotctl cannot pass -proxy, -registry-trust or -registry-fingerprint), under
# a small respawn loop detached with setsid. Output goes to ~/.pilot/daemon.log.
# A clean exit (for example `pilotctl daemon stop`) is not respawned. A pid file
# is trusted only when the process's command line matches, so pid files left
# behind by a VM restart are removed, never signalled.
#
# Environment (all optional):
#   PILOT_UP_MODE               auto (default) | native | direct | sni
#   PILOT_UP_TRANSPORT          native/direct -transport: auto | compat
#                               (default: auto when pilot-daemon -h offers it)
#   PILOT_UP_WAIT               seconds to wait for registration (default 60)
#   PILOT_PROXY                 native path: auto (default) | off | proxy URL
#   PILOT_HOSTNAME              node hostname (-hostname)
#   PILOT_SOCKET                IPC socket (default: config.json, else /tmp/pilot.sock)
#   PILOT_REGISTRY_TRUST        system | pinned (default: system, pinned on x509)
#   PILOT_REGISTRY_FINGERPRINT  registry leaf SHA-256 for pinned (default: bundled)
#   PILOT_BIN_DIR               pilotctl + pilot-daemon location (default ~/.pilot/bin)
#
# Exit codes: 0 online, 1 not online (log tail and next step printed),
# 2 usage error or missing binaries, 3 the only viable path needs root.
# Proxy credentials are never printed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PILOT_DIR="$HOME/.pilot"
BIN_DIR="${PILOT_BIN_DIR:-$PILOT_DIR/bin}"
DAEMON="$BIN_DIR/pilot-daemon"
PILOTCTL="$BIN_DIR/pilotctl"
LOG="$PILOT_DIR/daemon.log"
SUP_PID_FILE="$PILOT_DIR/pilot-up.pid"
DAEMON_PID_FILE="$PILOT_DIR/pilot.pid" # the file `pilotctl daemon stop|status` reads
ROUTER_PID_FILE="$PILOT_DIR/sni_router.pid"
ROUTER_LOG="$PILOT_DIR/sni_router.log"
REGISTRY="registry.pilotprotocol.network:443"
# Leaf certificate of registry.pilotprotocol.network, observed 2026-09-23 and
# valid until 2026-12-16: the pin the first Muse node registered with. After a
# renewal, re-fetch it with the snippet in references/troubleshooting.md.
BUNDLED_FINGERPRINT="c1f958f6bcff667cf6a08d5066cc031a9086115a7667835877ca62a3019b3da9"
MODE="${PILOT_UP_MODE:-auto}"
WAIT="${PILOT_UP_WAIT:-60}"
TRUST="${PILOT_REGISTRY_TRUST:-system}"
TRUST_FALLBACK=0
if [ -z "${PILOT_REGISTRY_TRUST:-}" ]; then TRUST_FALLBACK=1; fi
FINGERPRINT="${PILOT_REGISTRY_FINGERPRINT:-$BUNDLED_FINGERPRINT}"
FP_SOURCE="bundled"
if [ -n "${PILOT_REGISTRY_FINGERPRINT:-}" ]; then FP_SOURCE="PILOT_REGISTRY_FINGERPRINT"; fi
TRANSPORT_WANT="${PILOT_UP_TRANSPORT:-}"
TRANSPORT="compat"
VERSION=""
VERSION_TAG="unknown version"
TROUBLESHOOTING="$(dirname "$SCRIPT_DIR")/references/troubleshooting.md"

LOG_OFFSET=0
NODE_ADDR=""
NODE_ID=""
NODE_VERSION=""
DAEMON_HELP=""
CA_NOTE=""
ADOPTED=""
DETACH=(nohup)
if command -v setsid >/dev/null 2>&1; then
  DETACH=(setsid nohup)
fi

say() { printf 'pilot-up: %s\n' "$@"; }

# fail CODE LINE... — print each LINE to stderr and exit with CODE.
fail() {
  local code="$1"
  shift
  printf 'pilot-up: %s\n' "$@" >&2
  exit "$code"
}

# redact_url URL — URL with everything up to the last @ of the authority
# replaced by ***@ (a password may itself contain an unencoded @).
redact_url() {
  case "$1" in
    *://*@*) printf '%s://***@%s' "${1%%://*}" "${1##*@}" ;;
    *@*) printf '***@%s' "${1##*@}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# redact — the same for every URL in a stream (log tails). Greedy up to the
# last @ of each whitespace-delimited token.
redact() { sed -E 's#(://)[^[:space:]]*@#\1***@#g'; }

# proxy_url — the proxy the daemon's -proxy=auto would pick.
proxy_url() { printf '%s' "${HTTPS_PROXY:-${https_proxy:-${ALL_PROXY:-${all_proxy:-}}}}"; }

# no_proxy_covers_pilot — true when NO_PROXY would send Pilot traffic direct.
no_proxy_covers_pilot() {
  local item
  while IFS= read -r item; do
    [ "$item" = "*" ] && return 0
    item="${item#\*.}"
    item="${item#.}"
    case "$item" in
      pilotprotocol.network | registry.pilotprotocol.network | beacon.pilotprotocol.network) return 0 ;;
    esac
  done < <(printf '%s\n' "${NO_PROXY:-${no_proxy:-}}" | tr ', ' '\n')
  return 1
}

# config_value KEY — string value of KEY in ~/.pilot/config.json, or empty.
config_value() {
  local out
  out="$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$PILOT_DIR/config.json" 2>/dev/null || true)"
  out="${out%%$'\n'*}"
  out="${out%\"}"
  printf '%s' "${out##*\"}"
}

with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  else
    "$@"
  fi
}

# private_file FILE — create FILE if needed and make it owner-only (logs can
# hold hostnames and error text that should not be world-readable).
private_file() {
  (umask 077 && : >> "$1") 2>/dev/null || true
  chmod 600 "$1" 2>/dev/null || true
}

# --- pid files ---------------------------------------------------------------
# Every pid read from a file goes through valid_pid, and is only signalled when
# the live process's command line proves it is ours (is_supervisor, is_daemon,
# is_router). "0" is what a failed `pilotctl daemon start` leaves in pilot.pid,
# and `kill 0` would signal this script's whole process group, including
# whatever ran it (curl | bash, an agent's tool runner).

# own_pgid — this shell's process group id (empty when it cannot be read).
own_pgid() {
  local g="" stat fields
  g="$(ps -o pgid= -p "$$" 2>/dev/null || true)"
  g="${g//[[:space:]]/}"
  if [ -z "$g" ] && [ -r "/proc/$$/stat" ]; then
    stat="$(cat "/proc/$$/stat" 2>/dev/null || true)"
    read -r -a fields <<< "${stat##*) }" || true
    g="${fields[2]:-}"
  fi
  printf '%s' "$g"
}
MY_PGID="$(own_pgid)"

# valid_pid PID — true for a plain number above 1 that is neither this shell,
# its parent, nor its process group.
valid_pid() {
  case "$1" in '' | *[!0-9]*) return 1 ;; esac
  [ "${#1}" -le 9 ] || return 1
  local n=$((10#$1))
  [ "$n" -gt 1 ] && [ "$n" != "$$" ] && [ "$n" != "$PPID" ] && [ "$n" != "${MY_PGID:-}" ]
}

# read_pid FILE — the pid in FILE, or nothing when FILE is missing or does not
# hold a pid this script may signal.
read_pid() {
  local pid=""
  if [ -f "$1" ]; then
    { IFS= read -r pid; } < "$1" 2>/dev/null || true
  fi
  pid="${pid//[[:space:]]/}"
  if valid_pid "$pid"; then printf '%d' "$((10#$pid))"; fi
  return 0
}

# proc_args PID — PID's command line, one argument per line; empty when the
# process is gone or cannot be inspected (which never counts as a match).
proc_args() {
  if [ -r "/proc/$1/cmdline" ]; then
    tr '\0' '\n' < "/proc/$1/cmdline" 2>/dev/null || true
  elif [ ! -d /proc/self ]; then
    # No procfs (macOS dev boxes): ps, split on blanks. Best effort.
    ps -ww -o command= -p "$1" 2>/dev/null | tr ' ' '\n' || true
  fi
}

# is_supervisor PID — PID is this script's respawn loop for this ~/.pilot.
# shellcheck disable=SC2329 # called through live_pid/stop_pid
is_supervisor() {
  local args
  args="$(proc_args "$1")"
  grep -qx 'pilot-up-supervisor' <<< "$args" && grep -qxF "$SUP_PID_FILE" <<< "$args"
}

# is_daemon PID — PID is pilot-daemon (argv0 basename pilot-daemon or daemon,
# as pilotctl checks), or run-daemon.sh on its way to exec'ing it.
is_daemon() {
  local args argv0
  args="$(proc_args "$1")"
  argv0="${args%%$'\n'*}"
  argv0="${argv0##*/}"
  case "$argv0" in
    pilot-daemon | daemon) return 0 ;;
    unshare | bash | sh) grep -qE '(^|/)run-daemon\.sh$' <<< "$args" ;;
    *) return 1 ;;
  esac
}

# is_router PID — PID is sni_router.py.
# shellcheck disable=SC2329 # called through live_pid/stop_pid
is_router() { grep -qE '(^|/)sni_router\.py$' <<< "$(proc_args "$1")"; }

# live_pid FILE CHECK — the pid in FILE when that process is alive and CHECK
# recognises it; otherwise nothing.
live_pid() {
  local pid
  pid="$(read_pid "$1")"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && "$2" "$pid"; then
    printf '%s' "$pid"
  fi
  return 0
}

# drop_stale FILE CHECK — remove FILE when it names no live matching process
# (left behind by a VM restart, a crash, or a failed pilotctl daemon start).
drop_stale() {
  if [ -e "$1" ] && [ -z "$(live_pid "$1" "$2")" ]; then
    rm -f "$1"
    say "removed stale $1 (no matching live process)"
  fi
}

# wait_gone PID SECS — wait for PID to exit; false if it is still alive.
wait_gone() {
  local i=0
  while kill -0 "$1" 2>/dev/null; do
    [ "$i" -ge "$(($2 * 5))" ] && return 1
    sleep 0.2
    i=$((i + 1))
  done
}

# stop_pid PID CHECK SECS — SIGTERM, then SIGKILL after SECS if PID still
# passes CHECK (a pid reused in the meantime is left alone).
stop_pid() {
  kill -TERM "$1" 2>/dev/null || true
  if ! wait_gone "$1" "$3"; then
    if "$2" "$1"; then kill -KILL "$1" 2>/dev/null || true; fi
  fi
}

# --- daemon ------------------------------------------------------------------

file_size() {
  local n=0
  if [ -f "$1" ]; then n="$(wc -c < "$1")"; fi
  echo $((n + 0))
}

# new_log — daemon.log written since this run launched (or started waiting).
new_log() {
  if [ -f "$LOG" ]; then tail -c "+$((LOG_OFFSET + 1))" "$LOG" 2>/dev/null || true; fi
}

daemon_version() {
  local v
  v="$("$DAEMON" -version 2>&1 < /dev/null || true)"
  printf '%s' "${v%%$'\n'*}"
}

# version_token TEXT — the first vX.Y.Z-looking token in TEXT, or nothing.
version_token() {
  if [[ $1 =~ v?[0-9]+\.[0-9]+\.[0-9]+[-+.0-9A-Za-z]* ]]; then
    local v="${BASH_REMATCH[0]}"
    printf '%s' "${v#v}"
  fi
}

supports_proxy_flag() {
  grep -Eq '^[[:space:]]*-proxy([[:space:]]|$)' <<< "$DAEMON_HELP"
}

# supports_transport_auto — the -transport usage in `pilot-daemon -h` offers
# "auto" (as a value or the default, not as part of a word like auto-detect).
supports_transport_auto() {
  local usage
  usage="$(awk '
    /^[ \t]*-transport([ \t]|$)/ { on = 1; print; next }
    on && /^  -[a-zA-Z0-9]/ { exit }
    on { print }
  ' <<< "$DAEMON_HELP")"
  grep -Eq "(^|[^[:alnum:]_-])auto([^[:alnum:]_-]|$)" <<< "$usage"
}

pick_transport() {
  case "$TRANSPORT_WANT" in
    compat) TRANSPORT=compat ;;
    *)
      if supports_transport_auto; then
        TRANSPORT=auto
      else
        TRANSPORT=compat
        if [ "$TRANSPORT_WANT" = auto ]; then say "this pilot-daemon has no -transport=auto; using compat"; fi
      fi
      ;;
  esac
}

# node_online — true when the local daemon answers and is registered (its IPC
# socket only opens after registration). Sets NODE_ADDR, NODE_ID and
# NODE_VERSION (the version of the running daemon, not of the file on disk).
node_online() {
  local out
  out="$(with_timeout 15 "$PILOTCTL" --json info < /dev/null 2> /dev/null)" || return 1
  case "$out" in *'"status":"ok"'*) ;; *) return 1 ;; esac
  if [[ $out =~ \"address\":\"([^\"]*)\" ]]; then NODE_ADDR="${BASH_REMATCH[1]}"; fi
  if [[ $out =~ \"node_id\":([0-9]+) ]]; then NODE_ID="${BASH_REMATCH[1]}"; fi
  if [[ $out =~ \"version\":\"([^\"]*)\" ]]; then NODE_VERSION="${BASH_REMATCH[1]}"; fi
  return 0
}

# --- CA bundle -----------------------------------------------------------------

# go_finds_ca_bundle — true when Go's crypto/x509 on Linux will load system
# roots: SSL_CERT_FILE/SSL_CERT_DIR set, or one of its standard files or
# directories present.
go_finds_ca_bundle() {
  local f
  [ -n "${SSL_CERT_FILE:-}${SSL_CERT_DIR:-}" ] && return 0
  for f in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt \
    /etc/ssl/ca-bundle.pem /etc/pki/tls/cacert.pem \
    /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; do
    [ -s "$f" ] && return 0
  done
  for f in /etc/ssl/certs /etc/pki/tls/certs; do
    [ -d "$f" ] && [ -n "$(find -L "$f" -maxdepth 1 -type f -size +0 2>/dev/null | head -n 1)" ] && return 0
  done
  return 1
}

# find_ca_bundle — print the path of a PEM CA bundle found on this box.
find_ca_bundle() {
  local f py=()
  if command -v python3 >/dev/null 2>&1; then
    py+=("$(python3 -c 'import certifi; print(certifi.where())' 2>/dev/null || true)")
    py+=("$(python3 -c 'import ssl; p = ssl.get_default_verify_paths(); print(p.cafile or p.openssl_cafile)' 2>/dev/null || true)")
    py+=("$(python3 -c 'from pip._vendor import certifi; print(certifi.where())' 2>/dev/null || true)")
  fi
  for f in "${REQUESTS_CA_BUNDLE:-}" "${CURL_CA_BUNDLE:-}" ${py[@]+"${py[@]}"} \
    /usr/lib/ssl/cert.pem /usr/local/ssl/cert.pem /opt/conda/ssl/cacert.pem; do
    if [ -n "$f" ] && [ -s "$f" ] && grep -q 'BEGIN CERTIFICATE' "$f" 2>/dev/null; then
      printf '%s' "$f"
      return 0
    fi
  done
  # Node.js carries Mozilla's root store in its binary: write it out.
  f="$PILOT_DIR/ca-bundle.pem"
  if command -v node >/dev/null 2>&1 \
    && node -e 'process.stdout.write(require("tls").rootCertificates.join("\n") + "\n")' > "$f.tmp" 2>/dev/null \
    && grep -q 'BEGIN CERTIFICATE' "$f.tmp"; then
    mv -f "$f.tmp" "$f"
    printf '%s' "$f"
    return 0
  fi
  rm -f "$f.tmp"
  return 0
}

# ensure_ca_bundle — on Linux, when Go would find no CA bundle, export
# SSL_CERT_FILE for the daemon (system trust for the registry, and the beacon
# WSS, which has no pinned mode).
ensure_ca_bundle() {
  local f
  [ "$(uname -s 2>/dev/null)" = Linux ] || return 0
  go_finds_ca_bundle && return 0
  f="$(find_ca_bundle)"
  if [ -n "$f" ]; then
    export SSL_CERT_FILE="$f"
    say "no CA bundle where Go looks for one; using SSL_CERT_FILE=$f"
  else
    CA_NOTE=" (no CA bundle was found on this box)"
    say "warning: no CA bundle found; system TLS trust will fail (the registry can still be pinned, the beacon cannot)"
  fi
}

# --- launch ------------------------------------------------------------------

# supervise SUP_PID_FILE DAEMON_PID_FILE SOCKET CMD... — the respawn loop.
# Runs detached under `bash -c "$(declare -f supervise)" pilot-up-supervisor`
# (is_supervisor keys on that name). Restarts CMD when it crashes, stops on a
# clean exit or SIGTERM, and gives up after 5 fast failures in a row.
# shellcheck disable=SC2329 # invoked through declare -f in launch()
supervise() {
  local sup_pid_file="$1" daemon_pid_file="$2" socket="$3" rc started ran backoff=2 fails=0
  shift 3
  child=0
  stopping=0
  echo "$$" > "$sup_pid_file"
  trap 'stopping=1; [ "$child" -gt 0 ] && kill -TERM "$child" 2>/dev/null' TERM INT
  while [ "$stopping" = 0 ]; do
    rm -f "$socket"
    started="$(date +%s)"
    echo "pilot-up: $(date -u +%Y-%m-%dT%H:%M:%SZ) starting $*" | sed -E 's#(://)[^[:space:]]*@#\1***@#g'
    "$@" &
    child=$!
    echo "$child" > "$daemon_pid_file"
    rc=0
    wait "$child" || rc=$?
    if [ "$stopping" = 1 ]; then
      wait "$child" 2>/dev/null || true
      break
    fi
    child=0
    ran=$(($(date +%s) - started))
    case "$rc" in
      0 | 130 | 143)
        echo "pilot-up: daemon exited (rc=$rc); not respawning"
        break
        ;;
    esac
    if [ "$ran" -ge 120 ]; then
      backoff=2
      fails=0
    fi
    fails=$((fails + 1))
    if [ "$fails" -ge 5 ]; then
      echo "pilot-up: daemon failed $fails times in a row; giving up. Fix the cause, then rerun pilot-up.sh"
      break
    fi
    echo "pilot-up: daemon exited (rc=$rc) after ${ran}s; restarting in ${backoff}s"
    sleep "$backoff" &
    wait $! || true
    backoff=$((backoff * 2 > 60 ? 60 : backoff * 2))
  done
  rm -f "$daemon_pid_file" "$sup_pid_file"
}

# launch CMD... — start CMD under the respawn loop, detached from this shell.
launch() {
  local i=0
  if [ "$(file_size "$LOG")" -gt 5242880 ]; then mv -f "$LOG" "$LOG.1"; fi
  private_file "$LOG"
  LOG_OFFSET="$(file_size "$LOG")"
  rm -f "$SUP_PID_FILE"
  "${DETACH[@]}" bash -c "$(declare -f supervise); supervise \"\$@\"" pilot-up-supervisor \
    "$SUP_PID_FILE" "$DAEMON_PID_FILE" "$SOCKET" "$@" >> "$LOG" 2>&1 < /dev/null &
  while [ ! -s "$SUP_PID_FILE" ] && [ "$i" -lt 25 ]; do
    sleep 0.2
    i=$((i + 1))
  done
  say "respawn loop pid $(read_pid "$SUP_PID_FILE"), log $LOG"
}

# compat_args — the daemon command line shared by the native and direct paths.
compat_args() {
  ARGS=("$DAEMON" "-transport=$TRANSPORT" -registry "$REGISTRY" -registry-tls -registry-trust "$TRUST")
  if [ "$TRUST" = "pinned" ]; then
    ARGS+=(-registry-fingerprint "$FINGERPRINT")
  fi
  if [ -f "$PILOT_DIR/config.json" ]; then
    ARGS+=(-config "$PILOT_DIR/config.json")
  fi
  ARGS+=(-socket "$SOCKET" -identity "$PILOT_DIR/identity.json")
  if [ -n "${PILOT_HOSTNAME:-}" ]; then
    ARGS+=(-hostname "$PILOT_HOSTNAME")
  fi
}

start_native() {
  compat_args
  # -proxy=auto is the daemon default; pass it only when nothing else chose a
  # value, so PILOT_PROXY (read by the daemon from its environment) and a
  # "proxy" key in config.json still win and a proxy URL never lands in argv.
  if [ -z "${PILOT_PROXY:-}" ] && [ -z "$(config_value proxy)" ]; then
    ARGS+=(-proxy=auto)
  fi
  launch "${ARGS[@]}"
}

start_direct() {
  compat_args
  launch "${ARGS[@]}"
}

# needs_root REASON — the fallback is out of reach: say exactly what to do.
needs_root() {
  local alt="Rerun this script as root, keeping the proxy variables:
       sudo -E bash $SCRIPT_DIR/pilot-up.sh"
  if [ "$(id -u)" = 0 ]; then
    alt="Rerun this script where root has CAP_SYS_ADMIN (a VM, or a
     container started with --cap-add SYS_ADMIN)."
  fi
  cat >&2 <<MSG
pilot-up: cannot bring the node up from this shell.
  pilot-daemon ($VERSION_TAG) has no -proxy flag, so it cannot use
  the proxy in HTTPS_PROXY by itself, and the SNI-router fallback for older
  daemons needs root with CAP_SYS_ADMIN ($1).
Do one of:
  1. Upgrade to a Pilot release whose pilot-daemon has -proxy (the release
     after v1.13.9). The Muse installer works as root (it passes
     PILOT_ALLOW_ROOT=1 to the official installer) and restarts the node:
       curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | PILOT_UPGRADE=1 bash
  2. $alt
MSG
  exit 3
}

start_sni() {
  local proxy pid
  proxy="$(proxy_url)"
  [ -n "$proxy" ] || fail 1 "the sni path needs HTTPS_PROXY in the environment"
  if [ ! -f "$SCRIPT_DIR/sni_router.py" ] || [ ! -f "$SCRIPT_DIR/run-daemon.sh" ]; then
    fail 2 "sni_router.py and run-daemon.sh must sit next to this script" \
      "run it from the installed skill: bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh"
  fi
  if [ "$(id -u)" != 0 ]; then
    needs_root "this shell runs as $(id -un 2>/dev/null || id -u)"
  fi
  if ! command -v unshare >/dev/null 2>&1; then
    needs_root "unshare (util-linux) is not installed"
  fi
  if ! unshare -m true 2>/dev/null; then
    needs_root "root here, but 'unshare -m' is not permitted"
  fi
  command -v python3 >/dev/null 2>&1 || fail 1 "the sni path needs python3 for sni_router.py"

  pid="$(live_pid "$ROUTER_PID_FILE" is_router)"
  if [ -n "$pid" ]; then
    say "SNI router already running (pid $pid)"
  else
    rm -f "$ROUTER_PID_FILE"
    private_file "$ROUTER_LOG"
    # shellcheck disable=SC2016 # $$ and $@ belong to the inner shell
    HTTPS_PROXY="$proxy" "${DETACH[@]}" bash -c 'echo $$ > "$1"; shift; exec "$@"' sni-router \
      "$ROUTER_PID_FILE" python3 "$SCRIPT_DIR/sni_router.py" >> "$ROUTER_LOG" 2>&1 < /dev/null &
    sleep 1
    pid="$(live_pid "$ROUTER_PID_FILE" is_router)"
    if [ -z "$pid" ]; then
      tail -n 5 "$ROUTER_LOG" 2>/dev/null | redact >&2 || true
      fail 1 "sni_router.py exited at once (log $ROUTER_LOG)"
    fi
    say "SNI router pid $pid, log $ROUTER_LOG"
  fi
  export PILOT_BIN="$DAEMON" PILOT_REGISTRY_TRUST="$TRUST" PILOT_REGISTRY_FINGERPRINT="$FINGERPRINT"
  launch unshare -m bash "$SCRIPT_DIR/run-daemon.sh"
}

start_chosen() {
  local how="registry trust $TRUST"
  case "$CHOSEN" in native | direct) how="-transport=$TRANSPORT, $how" ;; esac
  say "pilot-daemon $VERSION_TAG: $CHOSEN path ($how)"
  case "$CHOSEN" in
    native) start_native ;;
    direct) start_direct ;;
    sni) start_sni ;;
  esac
}

# stop_daemon — stop the respawn loop and the daemon (validated pids only).
stop_daemon() {
  local pid
  pid="$(live_pid "$SUP_PID_FILE" is_supervisor)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_supervisor 15
    say "stopped respawn loop (pid $pid)"
  fi
  pid="$(live_pid "$DAEMON_PID_FILE" is_daemon)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_daemon 10
    say "stopped pilot-daemon (pid $pid)"
  fi
  rm -f "$SUP_PID_FILE" "$DAEMON_PID_FILE"
}

stop_all() {
  local pid
  stop_daemon
  pid="$(live_pid "$ROUTER_PID_FILE" is_router)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_router 5
    say "stopped SNI router (pid $pid)"
  fi
  rm -f "$ROUTER_PID_FILE"
}

# stop_foreign_daemon — a pilot-daemon from pilot.pid that is not registered
# (for example one `pilotctl daemon start` launched in UDP mode) would fight
# the one about to start over the socket and identity: stop it.
stop_foreign_daemon() {
  local pid
  pid="$(live_pid "$DAEMON_PID_FILE" is_daemon)"
  [ -n "$pid" ] || return 0
  say "stopping unregistered pilot-daemon pid $pid (not started by pilot-up)"
  with_timeout 20 "$PILOTCTL" --json daemon stop < /dev/null > /dev/null 2>&1 || true
  if kill -0 "$pid" 2>/dev/null && is_daemon "$pid"; then
    stop_pid "$pid" is_daemon 10
  fi
  rm -f "$DAEMON_PID_FILE"
}

# --- waiting and reporting ---------------------------------------------------

# registry_tls_failed — stdin (daemon log) has a registry TLS trust error.
registry_tls_failed() {
  grep -Eiq 'registry.*(x509|unknown authority|failed to verify certificate|fingerprint mismatch)|(x509|unknown authority|failed to verify certificate|fingerprint mismatch).*registry'
}

# wait_registered — poll pilotctl and the log. Returns 0 once registered, 2 on
# a registry TLS trust error, 1 when the loop died or time ran out.
wait_registered() {
  local deadline=$(($(date +%s) + WAIT)) next_note=$(($(date +%s) + 15)) text
  say "waiting up to ${WAIT}s for 'daemon registered' ..."
  while :; do
    if node_online; then return 0; fi
    text="$(new_log)"
    case "$text" in *"daemon registered"*)
      sleep 2
      node_online || true
      return 0
      ;;
    esac
    if registry_tls_failed <<< "$text"; then return 2; fi
    if [ -z "$(live_pid "$SUP_PID_FILE" is_supervisor)" ]; then
      node_online && return 0
      return 1
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then return 1; fi
    if [ "$(date +%s)" -ge "$next_note" ]; then
      say "still waiting ($((deadline - $(date +%s)))s left)"
      next_note=$((next_note + 15))
    fi
    sleep 2
  done
}

# next_step — the first diagnostic to try, from what the logs say.
next_step() {
  local text
  text="$(new_log)$(tail -n 20 "$ROUTER_LOG" 2>/dev/null || true)"
  case "$text" in
    *"Proxy Authentication Required"* | *" 407"* | *"407 "*)
      echo "the proxy rejected the credentials (407): check the user:pass part of HTTPS_PROXY" ;;
    *"fingerprint mismatch"*)
      echo "the registry certificate no longer matches the pinned fingerprint (it was renewed): re-fetch it into PILOT_REGISTRY_FINGERPRINT (snippet in references/troubleshooting.md), or use system trust with a CA bundle in SSL_CERT_FILE" ;;
    *x509:* | *"unknown authority"* | *"failed to verify certificate"*)
      if [ "$TRUST" = "pinned" ]; then
        echo "TLS trust failed outside the pinned registry (the beacon WSS cannot be pinned): export SSL_CERT_FILE=/path/to/ca-bundle.pem and rerun$CA_NOTE"
      else
        echo "TLS trust failed: export SSL_CERT_FILE=/path/to/ca-bundle.pem$CA_NOTE, or rerun with PILOT_REGISTRY_TRUST=pinned (bundled fingerprint)"
      fi
      ;;
    *"198.18."*)
      echo "the daemon dialed a poisoned address, so its traffic bypassed the proxy: export HTTPS_PROXY and keep pilotprotocol.network out of NO_PROXY" ;;
    *"refused CONNECT"* | *"CONNECT"*"403"* | *"403 Forbidden"* | *"405 Method"*)
      echo "the proxy refused the CONNECT: it must allow registry.pilotprotocol.network:443 and beacon.pilotprotocol.network:443" ;;
    *"mount --bind failed"*)
      echo "run-daemon.sh could not bind-mount /etc/hosts: rerun pilot-up.sh as root in a VM that grants CAP_SYS_ADMIN" ;;
    *"flag provided but not defined"*)
      echo "this pilot-daemon rejected a flag: rerun with PILOT_UP_MODE=sni (older daemon) or upgrade Pilot" ;;
    *)
      echo "read $LOG; if the proxy is just slow, rerun with PILOT_UP_WAIT=180" ;;
  esac
}

report_failure() {
  echo "--- last lines of $LOG ---" >&2
  new_log | tail -n 20 | redact >&2 || true
  if [ "$CHOSEN" = "sni" ]; then
    echo "--- last lines of $ROUTER_LOG ---" >&2
    tail -n 5 "$ROUTER_LOG" 2>/dev/null | redact >&2 || true
  fi
  echo "---" >&2
  fail 1 "next step: $(next_step)" \
    "then: bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh" \
    "notes: $TROUBLESHOOTING"
}

# report_online MESSAGE — the node answers: print where, and which daemon
# version is actually running (it can differ from the file on disk after an
# upgrade that did not restart the node).
report_online() {
  local disk running
  say "$1"
  printf '  %-8s %s\n' \
    address "${NODE_ADDR:-unknown}${NODE_ID:+ (node $NODE_ID)}" \
    daemon "running ${NODE_VERSION:-(version not reported)}" \
    log "$LOG" \
    check "$PILOTCTL --json info" \
    stop "bash $SCRIPT_DIR/pilot-up.sh --stop" \
    restart "rerun bash $SCRIPT_DIR/pilot-up.sh after every VM restart"
  disk="$(version_token "$VERSION")"
  running="$(version_token "$NODE_VERSION")"
  if [ -n "$disk" ] && [ -n "$running" ] && [ "$disk" != "$running" ]; then
    say "note: the running daemon is v$running but $DAEMON is v$disk; restart it to switch:" \
      "  bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh"
  fi
}

main() {
  case "${1:-}" in
    '') ;;
    --stop)
      stop_all
      exit 0
      ;;
    -h | --help)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]:-$0}"
      exit 0
      ;;
    *) fail 2 "unknown argument: $1 (try --help)" ;;
  esac
  case "$MODE" in auto | native | direct | sni) ;; *) fail 2 "PILOT_UP_MODE must be auto, native, direct or sni (got '$MODE')" ;; esac
  case "$WAIT" in '' | *[!0-9]*) fail 2 "PILOT_UP_WAIT must be a number of seconds (got '$WAIT')" ;; esac
  case "$TRUST" in system | pinned) ;; *) fail 2 "PILOT_REGISTRY_TRUST must be system or pinned (got '$TRUST')" ;; esac
  case "$TRANSPORT_WANT" in '' | auto | compat) ;; *) fail 2 "PILOT_UP_TRANSPORT must be auto or compat (got '$TRANSPORT_WANT')" ;; esac
  if ! [[ $FINGERPRINT =~ ^[0-9a-fA-F]{64}$ ]]; then
    fail 2 "PILOT_REGISTRY_FINGERPRINT must be 64 hex characters (the registry leaf SHA-256; fetch snippet in $TROUBLESHOOTING)"
  fi
  if [ ! -x "$DAEMON" ] || [ ! -x "$PILOTCTL" ]; then
    fail 2 "pilotctl and pilot-daemon not found in $BIN_DIR" \
      "install them: curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash"
  fi
  mkdir -p "$PILOT_DIR"
  SOCKET="${PILOT_SOCKET:-$(config_value socket)}"
  SOCKET="${SOCKET:-/tmp/pilot.sock}"
  export PILOT_SOCKET="$SOCKET"
  VERSION="$(daemon_version)"
  VERSION_TAG="$(version_token "$VERSION")"
  VERSION_TAG="${VERSION_TAG:+v$VERSION_TAG}"
  VERSION_TAG="${VERSION_TAG:-${VERSION:-unknown version}}"
  CHOSEN="$MODE"

  if node_online; then
    report_online "node already online"
    exit 0
  fi

  local proxy sup rc
  proxy="$(proxy_url)"
  if [ -n "$proxy" ]; then
    say "proxy: $(redact_url "$proxy")"
  else
    say "proxy: none in the environment (direct TCP/443)"
  fi
  if no_proxy_covers_pilot; then
    say "warning: NO_PROXY covers pilotprotocol.network, so Pilot traffic will skip the proxy"
  fi
  ensure_ca_bundle
  DAEMON_HELP="$("$DAEMON" -h 2>&1 < /dev/null || true)"
  pick_transport
  drop_stale "$SUP_PID_FILE" is_supervisor
  drop_stale "$DAEMON_PID_FILE" is_daemon
  drop_stale "$ROUTER_PID_FILE" is_router
  if [ "$CHOSEN" = "auto" ]; then
    if supports_proxy_flag; then
      CHOSEN="native"
    elif [ -z "$proxy" ]; then
      CHOSEN="direct"
    else
      CHOSEN="sni"
    fi
  fi

  sup="$(live_pid "$SUP_PID_FILE" is_supervisor)"
  if [ -n "$sup" ]; then
    say "respawn loop already running (pid $sup); waiting for it instead of starting another"
    ADOPTED="$sup"
    LOG_OFFSET="$(file_size "$LOG")"
  else
    stop_foreign_daemon
    start_chosen
  fi

  rc=0
  wait_registered || rc=$?
  if [ "$rc" = 2 ] && [ "$TRUST" = "system" ] && [ "$TRUST_FALLBACK" = 1 ]; then
    say "registry TLS failed with system trust (x509 error in $LOG)." \
      "retrying once with -registry-trust=pinned, fingerprint ${FINGERPRINT:0:12}... ($FP_SOURCE)." \
      "set PILOT_REGISTRY_TRUST=system or =pinned to choose explicitly."
    TRUST="pinned"
    ADOPTED=""
    stop_daemon
    start_chosen
    rc=0
    wait_registered || rc=$?
  fi
  if [ "$rc" = 0 ]; then
    if [ -n "$ADOPTED" ]; then
      report_online "node online (respawn loop pid $ADOPTED was already running)"
    else
      report_online "node online via the $CHOSEN path (registry trust $TRUST)"
    fi
    exit 0
  fi
  if [ -n "$ADOPTED" ]; then
    say "the node did not register within ${WAIT}s (respawn loop pid $ADOPTED, pilot-daemon $VERSION_TAG)" >&2
  else
    say "the node did not register within ${WAIT}s ($CHOSEN path, registry trust $TRUST, pilot-daemon $VERSION_TAG)" >&2
  fi
  report_failure
}

main "$@"
