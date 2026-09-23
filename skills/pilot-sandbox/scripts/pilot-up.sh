#!/usr/bin/env bash
# pilot-up.sh — bring this sandbox's Pilot node online, or confirm that it
# already is. Idempotent: rerun it after every VM restart (Meta Muse has no
# systemd, so nothing brings the daemon back on its own).
#
#   bash pilot-up.sh           start the node (or adopt a running one) and wait
#   bash pilot-up.sh --stop    stop the daemon, its respawn loop and the SNI router
#
# Launch paths, tried in this order (force one with PILOT_UP_MODE):
#   native  pilot-daemon has the -proxy flag: run it with -transport=compat
#           -proxy=auto. No root. The daemon asks the proxy in HTTPS_PROXY to
#           CONNECT by hostname, so the poisoned local DNS never matters.
#   direct  older pilot-daemon and no proxy in the environment: plain compat
#           mode, TCP/443 straight out.
#   sni     older pilot-daemon behind a proxy: sni_router.py plus
#           `unshare -m run-daemon.sh`. Needs root with CAP_SYS_ADMIN; without
#           it this script prints what to do instead and exits 3.
# The daemon is run directly, never through `pilotctl daemon start` (released
# versions scrub the environment, so HTTPS_PROXY would never reach it), under a
# small respawn loop detached with setsid. Output goes to ~/.pilot/daemon.log.
# A clean exit (for example `pilotctl daemon stop`) is not respawned.
#
# Environment (all optional):
#   PILOT_UP_MODE               auto (default) | native | direct | sni
#   PILOT_UP_WAIT               seconds to wait for registration (default 60)
#   PILOT_PROXY                 native path: auto (default) | off | proxy URL
#   PILOT_HOSTNAME              node hostname (-hostname)
#   PILOT_SOCKET                IPC socket (default: config.json, else /tmp/pilot.sock)
#   PILOT_REGISTRY_TRUST        system (default) | pinned
#   PILOT_REGISTRY_FINGERPRINT  registry leaf SHA-256, required with pinned
#   PILOT_BIN_DIR               pilotctl + pilot-daemon location (default ~/.pilot/bin)
#
# Exit codes: 0 online, 1 not online (log tail and next step printed),
# 2 usage error or missing binaries, 3 the only viable path needs root.
# Proxy credentials are never printed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PILOT_DIR="${PILOT_HOME:-$HOME}/.pilot"
BIN_DIR="${PILOT_BIN_DIR:-$PILOT_DIR/bin}"
DAEMON="$BIN_DIR/pilot-daemon"
PILOTCTL="$BIN_DIR/pilotctl"
LOG="$PILOT_DIR/daemon.log"
SUP_PID_FILE="$PILOT_DIR/pilot-up.pid"
DAEMON_PID_FILE="$PILOT_DIR/pilot.pid"   # the file `pilotctl daemon stop|status` reads
ROUTER_PID_FILE="$PILOT_DIR/sni_router.pid"
ROUTER_LOG="$PILOT_DIR/sni_router.log"
REGISTRY="registry.pilotprotocol.network:443"
MODE="${PILOT_UP_MODE:-auto}"
WAIT="${PILOT_UP_WAIT:-60}"
TRUST="${PILOT_REGISTRY_TRUST:-system}"
TROUBLESHOOTING="$(dirname "$SCRIPT_DIR")/references/troubleshooting.md"

LOG_OFFSET=0
NODE_ADDR=""
NODE_ID=""
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

# redact_url URL — URL with any user:pass@ replaced by ***@.
redact_url() {
  case "$1" in
    *://*@*) printf '%s://***@%s' "${1%%://*}" "${1##*@}" ;;
    *@*) printf '***@%s' "${1##*@}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# redact — the same for every URL in a stream (log tails).
redact() { sed -E 's#(://)[^/@[:space:]]*@#\1***@#g'; }

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

pid_of() { cat "$1" 2>/dev/null || true; }

# pid_alive FILE — true when FILE holds the pid of a live process.
pid_alive() {
  local pid
  pid="$(pid_of "$1")"
  case "$pid" in '' | *[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null
}

# looks_like_daemon PID — guard against a stale pid file naming a bystander.
looks_like_daemon() {
  local cmd
  [ -r "/proc/$1/cmdline" ] || return 0
  cmd="$(tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null || true)"
  case "$cmd" in *pilot-daemon* | *run-daemon.sh*) return 0 ;; esac
  return 1
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

supports_proxy_flag() {
  local help
  help="$("$DAEMON" -h 2>&1 < /dev/null || true)"
  grep -Eq '^[[:space:]]*-proxy([[:space:]]|$)' <<< "$help"
}

# node_online — true when the local daemon answers and is registered (its IPC
# socket only opens after registration). Sets NODE_ADDR and NODE_ID.
node_online() {
  local out
  out="$(with_timeout 15 "$PILOTCTL" --json info < /dev/null 2> /dev/null)" || return 1
  case "$out" in *'"status":"ok"'*) ;; *) return 1 ;; esac
  if [[ $out =~ \"address\":\"([^\"]*)\" ]]; then NODE_ADDR="${BASH_REMATCH[1]}"; fi
  if [[ $out =~ \"node_id\":([0-9]+) ]]; then NODE_ID="${BASH_REMATCH[1]}"; fi
  return 0
}

# supervise SUP_PID_FILE DAEMON_PID_FILE SOCKET CMD... — the respawn loop.
# Runs detached under `bash -c "$(declare -f supervise)"`. Restarts CMD when
# it crashes, stops on a clean exit or SIGTERM, and gives up after 5 fast
# failures in a row.
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
    echo "pilot-up: $(date -u +%Y-%m-%dT%H:%M:%SZ) starting $*" | sed -E 's#(://)[^/@[:space:]]*@#\1***@#g'
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
  LOG_OFFSET="$(file_size "$LOG")"
  rm -f "$SUP_PID_FILE"
  "${DETACH[@]}" bash -c "$(declare -f supervise); supervise \"\$@\"" pilot-up-supervisor \
    "$SUP_PID_FILE" "$DAEMON_PID_FILE" "$SOCKET" "$@" >> "$LOG" 2>&1 < /dev/null &
  while [ ! -s "$SUP_PID_FILE" ] && [ "$i" -lt 25 ]; do
    sleep 0.2
    i=$((i + 1))
  done
  say "respawn loop pid $(pid_of "$SUP_PID_FILE"), log $LOG"
}

# compat_args — the daemon command line shared by the native and direct paths.
compat_args() {
  ARGS=("$DAEMON" -transport=compat -registry "$REGISTRY" -registry-tls -registry-trust "$TRUST")
  if [ "$TRUST" = "pinned" ]; then
    ARGS+=(-registry-fingerprint "$PILOT_REGISTRY_FINGERPRINT")
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
  pilot-daemon (${VERSION:-unknown version}) has no -proxy flag, so it cannot use
  the proxy in HTTPS_PROXY by itself, and the SNI-router fallback for older
  daemons needs root with CAP_SYS_ADMIN ($1).
Do one of:
  1. Upgrade to a Pilot release whose pilot-daemon has -proxy (the release
     after v1.13.9), then rerun this script:
       curl -fsSL https://pilotprotocol.network/install.sh | sh
       bash $SCRIPT_DIR/pilot-up.sh
  2. $alt
MSG
  exit 3
}

start_sni() {
  local proxy
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

  if pid_alive "$ROUTER_PID_FILE"; then
    say "SNI router already running (pid $(pid_of "$ROUTER_PID_FILE"))"
  else
    rm -f "$ROUTER_PID_FILE"
    # shellcheck disable=SC2016 # $$ and $@ belong to the inner shell
    HTTPS_PROXY="$proxy" "${DETACH[@]}" bash -c 'echo $$ > "$1"; shift; exec "$@"' sni-router \
      "$ROUTER_PID_FILE" python3 "$SCRIPT_DIR/sni_router.py" >> "$ROUTER_LOG" 2>&1 < /dev/null &
    sleep 1
    if ! pid_alive "$ROUTER_PID_FILE"; then
      tail -n 5 "$ROUTER_LOG" 2>/dev/null | redact >&2 || true
      fail 1 "sni_router.py exited at once (log $ROUTER_LOG)"
    fi
    say "SNI router pid $(pid_of "$ROUTER_PID_FILE"), log $ROUTER_LOG"
  fi
  export PILOT_BIN="$DAEMON"
  launch unshare -m bash "$SCRIPT_DIR/run-daemon.sh"
}

stop_all() {
  local pid
  if pid_alive "$SUP_PID_FILE"; then
    pid="$(pid_of "$SUP_PID_FILE")"
    kill -TERM "$pid" 2>/dev/null || true
    wait_gone "$pid" 15 || kill -KILL "$pid" 2>/dev/null || true
    say "stopped respawn loop (pid $pid)"
  fi
  if pid_alive "$DAEMON_PID_FILE" && looks_like_daemon "$(pid_of "$DAEMON_PID_FILE")"; then
    pid="$(pid_of "$DAEMON_PID_FILE")"
    kill -TERM "$pid" 2>/dev/null || true
    wait_gone "$pid" 10 || kill -KILL "$pid" 2>/dev/null || true
    say "stopped pilot-daemon (pid $pid)"
  fi
  if pid_alive "$ROUTER_PID_FILE"; then
    pid="$(pid_of "$ROUTER_PID_FILE")"
    kill -TERM "$pid" 2>/dev/null || true
    say "stopped SNI router (pid $pid)"
  fi
  rm -f "$SUP_PID_FILE" "$DAEMON_PID_FILE" "$ROUTER_PID_FILE"
}

# wait_registered — poll pilotctl and the log until registration or timeout.
wait_registered() {
  local deadline=$(($(date +%s) + WAIT)) next_note=$(($(date +%s) + 15))
  say "waiting up to ${WAIT}s for 'daemon registered' ..."
  while :; do
    if node_online; then return 0; fi
    case "$(new_log)" in *"daemon registered"*)
      sleep 2
      node_online || true
      return 0
      ;;
    esac
    if ! pid_alive "$SUP_PID_FILE"; then
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
    *x509:* | *"certificate signed by unknown authority"*)
      echo "TLS trust failed: point SSL_CERT_FILE at a CA bundle, or use PILOT_REGISTRY_TRUST=pinned with PILOT_REGISTRY_FINGERPRINT (fetch snippet in references/troubleshooting.md)" ;;
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

report_online() {
  say "$1"
  printf '  %-8s %s\n' \
    address "${NODE_ADDR:-unknown}${NODE_ID:+ (node $NODE_ID)}" \
    log "$LOG" \
    check "$PILOTCTL --json info" \
    stop "bash $SCRIPT_DIR/pilot-up.sh --stop" \
    restart "rerun bash $SCRIPT_DIR/pilot-up.sh after every VM restart"
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
  if [ ! -x "$DAEMON" ] || [ ! -x "$PILOTCTL" ]; then
    fail 2 "pilotctl and pilot-daemon not found in $BIN_DIR" \
      "install them: curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash"
  fi
  mkdir -p "$PILOT_DIR"
  SOCKET="${PILOT_SOCKET:-$(config_value socket)}"
  SOCKET="${SOCKET:-/tmp/pilot.sock}"
  export PILOT_SOCKET="$SOCKET"
  VERSION="$(daemon_version)"
  CHOSEN="$MODE"

  if node_online; then
    report_online "node already online (pilot-daemon ${VERSION:-unknown})"
    exit 0
  fi

  local proxy pid
  proxy="$(proxy_url)"
  if [ -n "$proxy" ]; then
    say "proxy: $(redact_url "$proxy")"
  else
    say "proxy: none in the environment (direct TCP/443)"
  fi
  if no_proxy_covers_pilot; then
    say "warning: NO_PROXY covers pilotprotocol.network, so Pilot traffic will skip the proxy"
  fi

  if pid_alive "$SUP_PID_FILE"; then
    say "respawn loop already running (pid $(pid_of "$SUP_PID_FILE")); not starting another"
    CHOSEN="running"
    LOG_OFFSET="$(file_size "$LOG")"
  else
    if pid_alive "$DAEMON_PID_FILE" && looks_like_daemon "$(pid_of "$DAEMON_PID_FILE")"; then
      pid="$(pid_of "$DAEMON_PID_FILE")"
      say "stopping unregistered pilot-daemon pid $pid (not started by pilot-up)"
      with_timeout 20 "$PILOTCTL" --json daemon stop < /dev/null > /dev/null 2>&1 || kill -TERM "$pid" 2>/dev/null || true
      wait_gone "$pid" 10 || kill -KILL "$pid" 2>/dev/null || true
    fi
    if [ "$CHOSEN" = "auto" ]; then
      if supports_proxy_flag; then
        CHOSEN="native"
      elif [ -z "$proxy" ]; then
        CHOSEN="direct"
      else
        CHOSEN="sni"
      fi
    fi
    if [ "$TRUST" = "pinned" ] && [ "$CHOSEN" != "sni" ] && [ -z "${PILOT_REGISTRY_FINGERPRINT:-}" ]; then
      fail 2 "PILOT_REGISTRY_TRUST=pinned needs PILOT_REGISTRY_FINGERPRINT (fetch snippet in $TROUBLESHOOTING)"
    fi
    say "pilot-daemon ${VERSION:-unknown}: ${CHOSEN} path"
    case "$CHOSEN" in
      native) start_native ;;
      direct) start_direct ;;
      sni) start_sni ;;
    esac
  fi

  if wait_registered; then
    report_online "node online via the $CHOSEN path (pilot-daemon ${VERSION:-unknown})"
    exit 0
  fi
  say "the node did not register within ${WAIT}s ($CHOSEN path, pilot-daemon ${VERSION:-unknown})" >&2
  report_failure
}

main "$@"
