#!/usr/bin/env bash
# pilot-up.sh — bring this sandbox's Pilot node online, or confirm that it
# already is. Idempotent: rerun it after every VM restart (Meta Muse has no
# systemd, so nothing brings the daemon back on its own).
#
#   bash pilot-up.sh           start the node (or adopt a running one) and wait
#   bash pilot-up.sh --stop    stop the daemon, its respawn loop, the SNI router
#                              and the egress relay
#
# Launch paths, tried in this order (force one with PILOT_UP_MODE):
#   native  pilot-daemon has the -proxy flag: run it with -proxy=auto. No root.
#           The daemon asks the proxy in HTTPS_PROXY to CONNECT by hostname,
#           so the poisoned local DNS never matters.
#   direct  older pilot-daemon and no proxy in the environment: TCP/443
#           straight out.
#   sni     older pilot-daemon behind a proxy: sni_router.py plus
#           `unshare -m run-daemon.sh`. Needs root with CAP_SYS_ADMIN; without
#           it this script prints what to do instead and exits 3.
# Transport (native and direct): -transport=compat whenever a proxy is set (in
# the environment, PILOT_PROXY or config.json) or ~/.pilot/targets/muse exists.
# -transport=auto is not used there: it probes once and, when its check
# through the proxy fails (a 407, a slow proxy), settles on udp, which never
# uses the proxy. With no proxy: PILOT_TRANSPORT or config.json "transport" if
# set (left to the daemon), else -transport=auto when pilot-daemon -h offers
# it, else compat. PILOT_UP_TRANSPORT overrides all of this.
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
# Proxy credentials rotate in Meta Muse (every few minutes), and a running
# process keeps the ones it started with: its open tunnels survive while every
# new connection gets a 407 ("node online, all apps broken"). A fresh shell
# always sees the current ones, so the running pieces re-read them from one
# (PILOT_PROXY_CMD, default: bash -c 'printf %s "${https_proxy:-$HTTPS_PROXY}"'):
#   cmd     pilot-daemon -h lists -proxy-cmd (native path): the daemon runs
#           that command every 60s and after a 407. No extra process.
#   relay   any other daemon (sni path, or native without -proxy-cmd):
#           scripts/egress_relay.py on 127.0.0.1:3128 stamps fresh credentials
#           on every connection, and the SNI router and the daemon use it as
#           their proxy (no credentials in their environment; set at the last
#           exec, since a shell in between may re-export the real proxy). Needs
#           python3. A rerun restarts a relay that died, or whose re-read
#           credentials the proxy rejected, without touching the daemon.
#   static  neither is possible (or PILOT_PROXY / config.json names an explicit
#           proxy URL): the launch-time credentials.
# In cmd and static mode the respawn loop also re-reads them before each
# daemon (re)start.
# A salted hash of the proxy settings each piece depends on (not the
# credentials, in cmd and relay mode) is kept next to its pid file, so a rerun
# with other settings restarts it instead of reusing it. An online static-mode
# node run by pilot-up's respawn loop whose log shows the proxy rejecting its
# credentials (a 407) since its last start is restarted when this shell's
# credentials differ. A node pilot-up did not start only gets a note.
# --stop also stops a pilot-daemon that pilot-up did not start but that answers
# on the socket (found through the socket's owner), and an sni_router.py
# listening on the router port. It exits 1 when one could not be stopped. An
# egress_relay.py pilot-up did not start is used, never stopped.
#
# Environment (all optional):
#   PILOT_UP_MODE               auto (default) | native | direct | sni
#   PILOT_UP_TRANSPORT          native/direct -transport: compat | auto | udp
#                               (default: see Transport above)
#   PILOT_UP_WAIT               seconds to wait for registration (default 60)
#   PILOT_PROXY                 native path: auto (default) | off | proxy URL
#   PILOT_HOSTNAME              node hostname (-hostname)
#   PILOT_SOCKET                IPC socket (default: config.json, else /tmp/pilot.sock)
#   PILOT_REGISTRY_TRUST        system | pinned (default: system, pinned on x509)
#   PILOT_REGISTRY_FINGERPRINT  registry leaf SHA-256 for pinned (default: bundled)
#   PILOT_BIN_DIR               pilotctl + pilot-daemon location (default ~/.pilot/bin)
#   PILOT_SNI_LISTEN            SNI router address (default 127.0.0.1:443)
#   PILOT_UP_CREDS              auto (default) | cmd | relay | static (see above)
#   PILOT_PROXY_CMD             command printing the current proxy URL
#   PILOT_RELAY_LISTEN          egress relay address (default 127.0.0.1:3128)
#
# Exit codes: 0 online (--stop: everything stopped, or nothing was running),
# 1 not online (log tail and next step printed; --stop: something still runs),
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
SUP_PROXY_FILE="$PILOT_DIR/pilot-up.proxy"
ROUTER_PROXY_FILE="$PILOT_DIR/sni_router.proxy"
ROUTER_LISTEN="${PILOT_SNI_LISTEN:-127.0.0.1:443}"
RELAY_PID_FILE="$PILOT_DIR/egress_relay.pid"
RELAY_LOG="$PILOT_DIR/egress_relay.log"
RELAY_PROXY_FILE="$PILOT_DIR/egress_relay.proxy"
RELAY_LISTEN="${PILOT_RELAY_LISTEN:-127.0.0.1:3128}"
RELAY_URL="http://$RELAY_LISTEN"
# What pilot-daemon's -proxy-cmd, the egress relay and the respawn loop run to
# read the current proxy URL: a fresh shell sees credentials a running process
# does not. The official installer saves the same command as "proxy_cmd".
# shellcheck disable=SC2016 # expanded by that fresh shell, not here
SANDBOX_PROXY_CMD='bash -c '\''printf %s "${https_proxy:-$HTTPS_PROXY}"'\'''
CREDS_WANT="${PILOT_UP_CREDS:-auto}"
CRED_MODE="none"
CRED_WHY=""
RELAY_ENV=()
REFRESH=""
MUSE_MARKER="$PILOT_DIR/targets/muse"
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
TRANSPORT_WHY=""
PROXY_SOURCE=""
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
STOPPED=0
STOP_FAILED=0
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

# behind_proxy — this host's Pilot traffic has to go through a proxy: one is in
# the environment, PILOT_PROXY or config.json names one, or muse/install.sh
# marked the host as a Muse VM. Sets PROXY_SOURCE.
behind_proxy() {
  local v
  if [ -n "$(proxy_url)" ]; then
    PROXY_SOURCE="proxy in the environment"
    return 0
  fi
  v="$(printf '%s' "${PILOT_PROXY:-}" | tr '[:upper:]' '[:lower:]')"
  case "$v" in http://* | https://*)
    PROXY_SOURCE="PILOT_PROXY"
    return 0
    ;;
  esac
  v="$(config_value proxy | tr '[:upper:]' '[:lower:]')"
  case "$v" in http://* | https://*)
    PROXY_SOURCE="proxy in config.json"
    return 0
    ;;
  esac
  if [ -e "$MUSE_MARKER" ]; then
    PROXY_SOURCE="Muse host, $MUSE_MARKER"
    return 0
  fi
  return 1
}

# --- rotating proxy credentials ------------------------------------------------

# proxy_hostport URL — host:port of URL, without scheme, credentials or path.
proxy_hostport() {
  local u="${1#*://}"
  u="${u##*@}"
  printf '%s' "${u%%/*}"
}

# points_at_relay — this shell's proxy is the egress relay's own address (the
# manual relay recipe exports it), so it cannot tell the relay the real one.
points_at_relay() {
  local port="${RELAY_LISTEN##*:}"
  case "$(proxy_hostport "$(proxy_url)")" in
    "$RELAY_LISTEN" | "127.0.0.1:$port" | "localhost:$port" | "[::1]:$port") return 0 ;;
  esac
  return 1
}

supports_proxy_cmd() {
  grep -Eq '^[[:space:]]*-proxy-cmd([[:space:]]|$)' <<< "$DAEMON_HELP"
}

# config_proxy_cmd — "proxy_cmd" in ~/.pilot/config.json (the official
# installer saves one in sandboxes), JSON-decoded when python3 is there.
config_proxy_cmd() {
  [ -f "$PILOT_DIR/config.json" ] || return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys
v = json.load(open(sys.argv[1])).get("proxy_cmd")
sys.stdout.write(v.strip() if isinstance(v, str) else "")' "$PILOT_DIR/config.json" 2>/dev/null || true
  else
    config_value proxy_cmd
  fi
}

# effective_proxy_cmd — the command that prints the current proxy URL, in
# pilot-daemon's precedence: PILOT_PROXY_CMD, config.json "proxy_cmd", else
# the sandbox default (which pilot-up passes as -proxy-cmd).
effective_proxy_cmd() {
  local c="${PILOT_PROXY_CMD:-}"
  [ -n "${c//[[:space:]]/}" ] || c="$(config_proxy_cmd)"
  [ -n "${c//[[:space:]]/}" ] || c="$SANDBOX_PROXY_CMD"
  printf '%s' "$c"
}

# explicit_proxy_url — the daemon's proxy setting (PILOT_PROXY, else
# config.json "proxy") is a URL, which it uses as is.
explicit_proxy_url() {
  local v="${PILOT_PROXY:-}"
  [ -n "$v" ] || v="$(config_value proxy)"
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in http://* | https://*) return 0 ;; esac
  return 1
}

# relay_usable — egress_relay.py can run here: python3, the script, and a
# plain http:// proxy (the relay does not speak TLS to the proxy).
relay_usable() {
  { command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/egress_relay.py" ]; } || return 1
  case "$(proxy_url | tr '[:upper:]' '[:lower:]')" in https://*) return 1 ;; esac
  return 0
}

# pick_creds — how the node's long-lived processes get current proxy
# credentials (cmd, relay or static; none without a proxy). Needs CHOSEN and
# DAEMON_HELP. Sets CRED_MODE and CRED_WHY.
pick_creds() {
  CRED_MODE=none
  CRED_WHY=""
  case "$CHOSEN" in native | sni) ;; *) return 0 ;; esac
  [ -n "$(proxy_url)" ] || return 0
  if points_at_relay; then
    CRED_MODE=relay
    CRED_WHY="this shell's HTTPS_PROXY is the relay"
    return 0
  fi
  case "$CREDS_WANT" in
    cmd)
      if [ "$CHOSEN" != native ] || ! supports_proxy_cmd; then
        fail 2 "PILOT_UP_CREDS=cmd needs the native path and a pilot-daemon whose -h lists -proxy-cmd"
      fi
      CRED_MODE=cmd
      CRED_WHY="PILOT_UP_CREDS"
      ;;
    relay)
      relay_usable || fail 2 "PILOT_UP_CREDS=relay needs python3, scripts/egress_relay.py and an http:// proxy"
      CRED_MODE=relay
      CRED_WHY="PILOT_UP_CREDS"
      ;;
    static)
      CRED_MODE=static
      CRED_WHY="PILOT_UP_CREDS"
      ;;
    *)
      if [ "$CHOSEN" = native ] && explicit_proxy_url; then
        CRED_MODE=static
        CRED_WHY="PILOT_PROXY or config.json names the proxy URL"
      elif [ "$CHOSEN" = native ] && supports_proxy_cmd; then
        CRED_MODE=cmd
        CRED_WHY="pilot-daemon has -proxy-cmd"
      elif relay_usable; then
        CRED_MODE=relay
        CRED_WHY="pilot-daemon cannot re-read them itself"
      else
        CRED_MODE=static
        CRED_WHY="no -proxy-cmd, and no python3 for the relay"
      fi
      ;;
  esac
}

# creds_desc MODE — how a node started in MODE gets its proxy credentials.
creds_desc() {
  case "$1" in
    cmd) printf 're-read by pilot-daemon (-proxy-cmd) every 60s and after a 407' ;;
    relay) printf 'stamped fresh on every connection by the egress relay %s' "$RELAY_URL" ;;
    static) printf 'the ones it started with (after a rotation, rerun this from a fresh shell)' ;;
  esac
}

# relay_env — sets RELAY_ENV, an `env ...` command prefix that makes the
# egress relay the proxy of the command it runs, with no credentials in its
# environment (children it spawns inherit that too). It is applied at the
# last exec, not to a shell above it: in Muse a fresh shell re-reads the real
# proxy, and would put it back over the relay's address. run-daemon.sh
# re-applies PILOT_DAEMON_PROXY for the same reason.
relay_env() {
  local np="${NO_PROXY:-${no_proxy:-}}" h
  for h in localhost 127.0.0.1; do
    case ",$np," in *",$h,"*) ;; *) np="${np:+$np,}$h" ;; esac
  done
  RELAY_ENV=(env -u ALL_PROXY -u all_proxy
    "HTTPS_PROXY=$RELAY_URL" "https_proxy=$RELAY_URL" "HTTP_PROXY=$RELAY_URL" "http_proxy=$RELAY_URL"
    "NO_PROXY=$np" "no_proxy=$np" "PILOT_DAEMON_PROXY=$RELAY_URL")
}

# refresh_proxy_env CMD — used by the respawn loop before each start: export
# the proxy URL CMD prints (run by sh, so a fresh shell reads it) as
# HTTPS_PROXY / https_proxy, and as HTTP_PROXY / http_proxy where those held
# the same URL. Never prints the value.
# shellcheck disable=SC2329 # invoked through declare -f in launch()
refresh_proxy_env() {
  local fresh old v
  if command -v timeout > /dev/null 2>&1; then
    fresh="$(timeout 10 sh -c "$1" < /dev/null 2> /dev/null || true)"
  else
    fresh="$(sh -c "$1" < /dev/null 2> /dev/null || true)"
  fi
  fresh="${fresh%%$'\n'*}"
  fresh="${fresh//[[:space:]]/}"
  case "$fresh" in *://?*) ;; *) return 0 ;; esac
  old="${HTTPS_PROXY:-${https_proxy:-}}"
  [ "$fresh" != "$old" ] || return 0
  for v in HTTP_PROXY http_proxy; do
    if [ -n "${!v:-}" ] && [ "${!v}" = "$old" ]; then export "$v=$fresh"; fi
  done
  export HTTPS_PROXY="$fresh" https_proxy="$fresh"
  echo "pilot-up: $(date -u +%Y-%m-%dT%H:%M:%SZ) proxy credentials re-read from a fresh shell for this start"
}

# --- proxy settings fingerprint ------------------------------------------------
# A long-lived process keeps the proxy settings it was started with. launch(),
# ensure_router() and ensure_relay() record a salted hash of the settings the
# process depends on next to its pid file, so a rerun from a shell whose
# settings differ restarts it instead of reusing it. In cmd and relay mode the
# credentials are not part of it: those processes re-read them, so a rotation
# restarts nothing.

hash_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r
  else
    cksum
  fi 2>/dev/null | awk '{ print $1; exit }'
}

# settings_for MODE PATH — the proxy settings a piece started in credential
# MODE on launch PATH depends on, as one line (hashed, never stored):
#   static, none  the proxy URL itself (credentials included)
#   cmd           the proxy without its credentials, and the command that
#                 re-reads them
#   relay         the relay's address (the daemon and router never see the
#                 real proxy)
#   relayd        the relay process: its address and credential command
settings_for() {
  local np="${NO_PROXY:-${no_proxy:-}}"
  case "$1" in
    cmd) printf 'cmd|%s|%s|%s|%s|%s' "$2" "$(redact_url "$(proxy_url)")" "${PILOT_PROXY:-}" "$np" "$(effective_proxy_cmd)" ;;
    relay) printf 'relay|%s|%s|%s|%s' "$2" "$RELAY_LISTEN" "${PILOT_PROXY:-}" "$np" ;;
    relayd) printf 'relayd|%s|%s' "$RELAY_LISTEN" "${PILOT_PROXY_CMD:-}" ;;
    *) printf '%s|%s|%s|%s|%s' "$1" "$2" "$(proxy_url)" "${PILOT_PROXY:-}" "$np" ;;
  esac
}

# write_fp FILE MODE [PATH] — record, in FILE, a salted hash of the settings
# (settings_for MODE PATH) followed by MODE and PATH.
write_fp() {
  local salt
  salt="$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || true)"
  salt="${salt:-$$.$RANDOM.$RANDOM}"
  private_file "$1"
  printf '%s %s %s %s\n' "$salt" "$(printf '%s|%s' "$salt" "$(settings_for "$2" "${3:-}")" | hash_stdin)" \
    "$2" "${3:--}" > "$1" 2>/dev/null || true
}

# recorded FILE FIELD — the MODE (3) or PATH (4) a fingerprint file recorded.
recorded() {
  local salt="" sum="" mode="" path=""
  if [ -f "$1" ]; then read -r salt sum mode path < "$1" 2>/dev/null || true; fi
  case "$2" in 3) printf '%s' "$mode" ;; 4) [ "$path" = - ] || printf '%s' "$path" ;; esac
  return 0
}

# fp_matches FILE [MODE [PATH]] — FILE records this shell's settings (for the
# mode and path it was written with), and that MODE and PATH when given.
fp_matches() {
  local salt="" sum="" mode="" path=""
  [ -f "$1" ] || return 1
  read -r salt sum mode path < "$1" 2>/dev/null || true
  [ -n "$salt" ] && [ -n "$sum" ] && [ -n "$mode" ] || return 1
  [ "$path" = - ] && path=""
  [ -z "${2:-}" ] || [ "$2" = "$mode" ] || return 1
  [ -z "${3:-}" ] || [ "$3" = "$path" ] || return 1
  [ "$(printf '%s|%s' "$salt" "$(settings_for "$mode" "$path")" | hash_stdin)" = "$sum" ]
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
# as pilotctl checks), or this skill's run-daemon.sh on its way to exec'ing it
# (run by unshare, bash or sh). A run-daemon.sh from any other directory
# belongs to something else.
is_daemon() {
  local args argv0 arg
  args="$(proc_args "$1")"
  argv0="${args%%$'\n'*}"
  argv0="${argv0##*/}"
  case "$argv0" in
    pilot-daemon | daemon) return 0 ;;
    unshare | bash | sh) ;;
    *) return 1 ;;
  esac
  case "$args" in *$'\n'*) ;; *) return 1 ;; esac
  while IFS= read -r arg; do
    case "$arg" in run-daemon.sh | */run-daemon.sh) ;; *) continue ;; esac
    if is_our_run_daemon "$1" "$arg"; then return 0; fi
  done <<< "${args#*$'\n'}"
  return 1
}

# is_our_run_daemon PID PATH — PATH, an argument of PID, is this skill's
# run-daemon.sh: the same file as $SCRIPT_DIR/run-daemon.sh, with a relative
# PATH resolved against PID's working directory (the old recipe ran
# ./scripts/run-daemon.sh from the skill directory). Without /proc a relative
# PATH never matches.
is_our_run_daemon() {
  local ours="$SCRIPT_DIR/run-daemon.sh"
  [ -f "$ours" ] || return 1
  case "$2" in
    /*) [ "$2" -ef "$ours" ] ;;
    *) [ -d "/proc/$1/cwd" ] && [ "/proc/$1/cwd/$2" -ef "$ours" ] ;;
  esac
}

# is_router PID — PID is sni_router.py.
# shellcheck disable=SC2329 # called through live_pid/stop_pid
is_router() { grep -qE '(^|/)sni_router\.py$' <<< "$(proc_args "$1")"; }

# is_relay PID — PID is egress_relay.py.
# shellcheck disable=SC2329 # called through live_pid/stop_pid
is_relay() { grep -qE '(^|/)egress_relay\.py$' <<< "$(proc_args "$1")"; }

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

# drop_stale FILE CHECK [FP_FILE] — remove FILE (and FP_FILE) when it names no
# live matching process (left behind by a VM restart, a crash, or a failed
# pilotctl daemon start).
drop_stale() {
  if [ -e "$1" ] && [ -z "$(live_pid "$1" "$2")" ]; then
    rm -f "$1" ${3:+"$3"}
    say "removed stale $1 (no matching live process)"
  fi
}

# pids_matching CHECK — every live process CHECK recognises (Linux /proc).
pids_matching() {
  local d pid
  for d in /proc/[0-9]*; do
    pid="${d#/proc/}"
    valid_pid "$pid" || continue
    if "$1" "$pid"; then printf '%s\n' "$pid"; fi
  done
  return 0
}

# holds_any PID LINKS — PID has an open fd whose link is one of LINKS
# (newline-separated socket:[inode] strings).
holds_any() {
  local fd link
  for fd in "/proc/$1/fd/"*; do
    link="$(readlink "$fd" 2>/dev/null)" || continue
    case "$link" in socket:*) grep -qxF -- "$link" <<< "$2" && return 0 ;; esac
  done
  return 1
}

# socket_owner_pids — every pilot-daemon (is_daemon) holding a socket bound to
# $SOCKET, found through /proc on Linux or lsof elsewhere, as `pilotctl daemon
# stop` does when it has no pid file. Usually one; a daemon that was started
# on the same path later rebinds it while the first keeps its (now unlinked)
# socket, and both are listed.
socket_owner_pids() {
  local links pid
  if [ -r /proc/net/unix ]; then
    links="$(awk -v p="$SOCKET" '
      { n = length(p) }
      length($0) > n && substr($0, length($0) - n) == " " p { print "socket:[" $7 "]" }
    ' /proc/net/unix 2>/dev/null || true)"
    [ -n "$links" ] || return 0
    for pid in $(pids_matching is_daemon); do
      if holds_any "$pid" "$links"; then printf '%s\n' "$pid"; fi
    done
  elif command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -t -U -a "$SOCKET" 2>/dev/null || true); do
      if valid_pid "$pid" && is_daemon "$pid"; then printf '%s\n' "$pid"; fi
    done
  fi
  return 0
}

# socket_owner_pid — the first of socket_owner_pids, or nothing.
socket_owner_pid() {
  local pids
  pids="$(socket_owner_pids)"
  printf '%s' "${pids%%$'\n'*}"
}

# listener_pids PORT CHECK — processes CHECK recognises that hold a TCP
# listener on PORT, whether or not a pid file names them.
listener_pids() {
  local port="$1" links pid
  case "$port" in '' | *[!0-9]*) return 0 ;; esac
  if [ -r /proc/net/tcp ]; then
    links="$(awk -v h=":$(printf '%04X' "$port")" '
      $4 == "0A" && substr($2, length($2) - 4) == h { print "socket:[" $10 "]" }
    ' /proc/net/tcp /proc/net/tcp6 2>/dev/null || true)"
    [ -n "$links" ] || return 0
    for pid in $(pids_matching "$2"); do
      if holds_any "$pid" "$links"; then printf '%s\n' "$pid"; fi
    done
  elif command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -nP -t -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true); do
      if valid_pid "$pid" && "$2" "$pid"; then printf '%s\n' "$pid"; fi
    done
  fi
  return 0
}

# router_listener_pids — sni_router.py processes holding the router's port.
router_listener_pids() { listener_pids "${ROUTER_LISTEN##*:}" is_router; }

# port_open HOST:PORT — something accepts TCP connections there.
port_open() {
  local host="${1%:*}"
  host="${host#[}"
  # shellcheck disable=SC2016 # $0 and $1 belong to the inner shell
  with_timeout 3 bash -c 'exec 3<> "/dev/tcp/$0/$1"' "${host%]}" "${1##*:}" 2>/dev/null
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

# pick_transport — -transport for the native and direct paths. Sets TRANSPORT
# (empty: none on argv, so the daemon's own PILOT_TRANSPORT / config.json
# choice stands) and TRANSPORT_WHY.
#   PILOT_UP_TRANSPORT  wins (auto needs a daemon that offers it)
#   behind a proxy      compat. -transport=auto makes one check through the
#                       proxy and settles on udp when it fails (a 407, a 502,
#                       a proxy slower than its timeout); udp never uses the
#                       proxy, so everything then dials the poisoned DNS
#                       directly and the sandbox's guard kills it.
#   PILOT_TRANSPORT or config.json "transport"  left to the daemon
#   otherwise           auto when pilot-daemon -h offers it, else compat
pick_transport() {
  local configured="" from=""
  if [ -n "${PILOT_TRANSPORT:-}" ]; then
    configured="$(printf '%s' "$PILOT_TRANSPORT" | tr '[:upper:]' '[:lower:]')"
    from="PILOT_TRANSPORT"
  else
    configured="$(config_value transport | tr '[:upper:]' '[:lower:]')"
    from="config.json"
  fi
  if [ -n "$TRANSPORT_WANT" ]; then
    TRANSPORT="$TRANSPORT_WANT"
    TRANSPORT_WHY="PILOT_UP_TRANSPORT"
    if [ "$TRANSPORT" = auto ] && ! supports_transport_auto; then
      TRANSPORT=compat
      TRANSPORT_WHY="this pilot-daemon has no -transport=auto"
      say "PILOT_UP_TRANSPORT=auto: this pilot-daemon has no -transport=auto; using compat"
    fi
  elif behind_proxy; then
    TRANSPORT=compat
    TRANSPORT_WHY="$PROXY_SOURCE"
    if [ -n "$configured" ] && [ "$configured" != compat ]; then
      say "note: $from sets transport $configured; using compat, the only transport that always goes through the proxy (PILOT_UP_TRANSPORT=$configured to insist)"
    fi
  elif [ -n "$configured" ]; then
    TRANSPORT=""
    TRANSPORT_WHY="$from"
  elif supports_transport_auto; then
    TRANSPORT=auto
    TRANSPORT_WHY="no proxy"
  else
    TRANSPORT=compat
    TRANSPORT_WHY="no proxy"
  fi
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

# supervise SUP_PID_FILE DAEMON_PID_FILE SOCKET REFRESH CMD... — the respawn
# loop. Runs detached under `bash -c "$(declare -f ...)" pilot-up-supervisor`
# (is_supervisor keys on that name). Before each start it re-reads the proxy
# credentials with the command REFRESH (none when empty: relay mode, or no
# proxy), so a daemon restarted after a rotation never gets stale ones.
# Restarts CMD when it crashes, stops on a clean exit or SIGTERM, and gives up
# after 5 fast failures in a row.
# shellcheck disable=SC2329 # invoked through declare -f in launch()
supervise() {
  local sup_pid_file="$1" daemon_pid_file="$2" socket="$3" refresh="$4" rc started ran backoff=2 fails=0
  shift 4
  child=0
  stopping=0
  echo "$$" > "$sup_pid_file"
  trap 'stopping=1; [ "$child" -gt 0 ] && kill -TERM "$child" 2>/dev/null' TERM INT
  while [ "$stopping" = 0 ]; do
    rm -f "$socket"
    if [ -n "$refresh" ]; then refresh_proxy_env "$refresh"; fi
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

# launch CMD... — start CMD under the respawn loop, detached from this shell,
# with REFRESH (see supervise).
launch() {
  local i=0
  if [ "$(file_size "$LOG")" -gt 5242880 ]; then mv -f "$LOG" "$LOG.1"; fi
  private_file "$LOG"
  LOG_OFFSET="$(file_size "$LOG")"
  rm -f "$SUP_PID_FILE"
  write_fp "$SUP_PROXY_FILE" "$CRED_MODE" "$CHOSEN"
  "${DETACH[@]}" bash -c "$(declare -f supervise refresh_proxy_env); supervise \"\$@\"" pilot-up-supervisor \
    "$SUP_PID_FILE" "$DAEMON_PID_FILE" "$SOCKET" "$REFRESH" "$@" >> "$LOG" 2>&1 < /dev/null &
  while [ ! -s "$SUP_PID_FILE" ] && [ "$i" -lt 25 ]; do
    sleep 0.2
    i=$((i + 1))
  done
  say "respawn loop pid $(read_pid "$SUP_PID_FILE"), log $LOG"
}

# compat_args — the daemon command line shared by the native and direct paths.
compat_args() {
  ARGS=("$DAEMON")
  if [ -n "$TRANSPORT" ]; then
    ARGS+=("-transport=$TRANSPORT")
  fi
  ARGS+=(-registry "$REGISTRY" -registry-tls -registry-trust "$TRUST")
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
  local pc="${PILOT_PROXY_CMD:-}"
  compat_args
  # -proxy=auto is the daemon default; pass it only when nothing else chose a
  # value, so PILOT_PROXY (read by the daemon from its environment) and a
  # "proxy" key in config.json still win and a proxy URL never lands in argv.
  if [ -z "${PILOT_PROXY:-}" ] && [ -z "$(config_value proxy)" ]; then
    ARGS+=(-proxy=auto)
  fi
  case "$CRED_MODE" in
    cmd)
      # The daemon reads PILOT_PROXY_CMD and config.json "proxy_cmd" itself;
      # pass the sandbox default only when neither sets one.
      if [ -z "${pc//[[:space:]]/}" ] && [ -z "$(config_proxy_cmd)" ]; then
        ARGS+=(-proxy-cmd "$SANDBOX_PROXY_CMD")
      fi
      ;;
    relay)
      ensure_relay
      relay_env
      ARGS=("${RELAY_ENV[@]}" "${ARGS[@]}")
      ;;
  esac
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

# ensure_relay [quiet] — egress_relay.py listens on RELAY_LISTEN: pilot-up's
# own (restarted when it was started with other settings), or one started by
# hand, which is used as is and never stopped. Starts pilot-up's otherwise.
# quiet: say nothing when pilot-up's relay is already running.
ensure_relay() {
  local pid i=0 cred=()
  pid="$(live_pid "$RELAY_PID_FILE" is_relay)"
  if [ -n "$pid" ] && fp_matches "$RELAY_PROXY_FILE" relayd && ! relay_rejected; then
    [ -n "${1:-}" ] || say "egress relay already running (pid $pid, $RELAY_LISTEN)"
    return 0
  fi
  if [ -n "$pid" ] && relay_rejected; then
    # Its fresh shells keep printing rejected credentials: start it again
    # from this shell, whose environment has current ones.
    say "restarting the egress relay (pid $pid): the proxy rejected the credentials it re-read ($RELAY_LOG)"
    stop_relay
  elif [ -n "$pid" ]; then
    say "restarting the egress relay (pid $pid): it was started with other settings"
    stop_relay
  elif [ -n "${1:-}" ]; then
    say "the egress relay this node uses is not running"
  fi
  rm -f "$RELAY_PID_FILE" "$RELAY_PROXY_FILE"
  pid="$(listener_pids "${RELAY_LISTEN##*:}" is_relay)"
  if [ -n "$pid" ]; then
    say "using the egress relay already listening on $RELAY_LISTEN (pid ${pid%%$'\n'*}; not started by pilot-up, so --stop leaves it running)"
    return 0
  fi
  if port_open "$RELAY_LISTEN"; then
    if points_at_relay; then
      say "using the proxy listening on $RELAY_LISTEN (this shell's HTTPS_PROXY; not started by pilot-up)"
      return 0
    fi
    fail 1 "$RELAY_LISTEN is taken by a process that is not egress_relay.py: set PILOT_RELAY_LISTEN=127.0.0.1:<free port> and rerun"
  fi
  if points_at_relay; then
    fail 1 "this shell's HTTPS_PROXY is the egress relay's address ($RELAY_LISTEN), and nothing listens there." \
      "  The relay needs the sandbox's own proxy: rerun from a new shell whose HTTPS_PROXY is the real proxy (pilot-up starts the relay itself)."
  fi
  private_file "$RELAY_LOG"
  write_fp "$RELAY_PROXY_FILE" relayd
  if [ -n "${PILOT_PROXY_CMD:-}" ]; then cred=("RELAY_CRED_CMD=$PILOT_PROXY_CMD"); fi
  # The relay keeps this shell's environment: its fresh shells read the real
  # proxy from it.
  # shellcheck disable=SC2016 # $$ and $@ belong to the inner shell
  env RELAY_LISTEN="$RELAY_LISTEN" RELAY_LOG="$RELAY_LOG" ${cred[@]+"${cred[@]}"} \
    "${DETACH[@]}" bash -c 'echo $$ > "$1"; shift; exec "$@"' egress-relay \
    "$RELAY_PID_FILE" python3 "$SCRIPT_DIR/egress_relay.py" >> "$RELAY_LOG" 2>&1 < /dev/null &
  pid=""
  while [ "$i" -lt 25 ]; do
    sleep 0.2
    pid="$(live_pid "$RELAY_PID_FILE" is_relay)"
    if [ -n "$pid" ] && port_open "$RELAY_LISTEN"; then break; fi
    if [ -s "$RELAY_PID_FILE" ] && [ -z "$pid" ]; then break; fi
    i=$((i + 1))
  done
  if [ -z "$pid" ] || ! port_open "$RELAY_LISTEN"; then
    tail -n 5 "$RELAY_LOG" 2>/dev/null | redact >&2 || true
    fail 1 "egress_relay.py did not start listening on $RELAY_LISTEN (log $RELAY_LOG)"
  fi
  say "egress relay pid $pid on $RELAY_LISTEN: it stamps current proxy credentials on every connection (log $RELAY_LOG)"
}

# relay_rejected — pilot-up's relay logged, since it started, that the proxy
# rejected even the credentials it had just re-read.
relay_rejected() {
  since_marker "$RELAY_LOG" 'listening on ' | grep -q 'rejected after re-reading'
}

# stop_relay — stop pilot-up's egress relay (from its pid file only).
stop_relay() {
  local pid
  pid="$(live_pid "$RELAY_PID_FILE" is_relay)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_relay 5
    say "stopped egress relay (pid $pid)"
    STOPPED=$((STOPPED + 1))
  fi
  rm -f "$RELAY_PID_FILE" "$RELAY_PROXY_FILE"
}

# ensure_router — the SNI router runs with this shell's settings for
# CRED_MODE; one started with others is restarted, as is one started by hand
# that holds the router port. In relay mode its proxy is the egress relay.
ensure_router() {
  local proxy pid
  pid="$(live_pid "$ROUTER_PID_FILE" is_router)"
  if [ -n "$pid" ] && fp_matches "$ROUTER_PROXY_FILE" "$CRED_MODE" sni; then
    say "SNI router already running (pid $pid)"
    return 0
  fi
  if [ -n "$pid" ]; then
    say "restarting the SNI router (pid $pid): it was started with different proxy settings (for example credentials that have rotated since)"
  fi
  STOP_FAILED=0
  stop_router
  if [ "$STOP_FAILED" != 0 ]; then
    fail 1 "cannot start the SNI router while the process above holds port ${ROUTER_LISTEN##*:}"
  fi
  proxy="$(proxy_url)"
  RELAY_ENV=()
  if [ "$CRED_MODE" = relay ]; then
    proxy="$RELAY_URL"
    relay_env
  fi
  private_file "$ROUTER_LOG"
  write_fp "$ROUTER_PROXY_FILE" "$CRED_MODE" sni
  # The proxy URL goes in the environment (it can carry credentials); in relay
  # mode RELAY_ENV sets it again at the last exec.
  # shellcheck disable=SC2016 # $$ and $@ belong to the inner shell
  HTTPS_PROXY="$proxy" "${DETACH[@]}" bash -c 'echo $$ > "$1"; shift; exec "$@"' sni-router \
    "$ROUTER_PID_FILE" ${RELAY_ENV[@]+"${RELAY_ENV[@]}"} python3 "$SCRIPT_DIR/sni_router.py" >> "$ROUTER_LOG" 2>&1 < /dev/null &
  sleep 1
  pid="$(live_pid "$ROUTER_PID_FILE" is_router)"
  if [ -z "$pid" ]; then
    tail -n 5 "$ROUTER_LOG" 2>/dev/null | redact >&2 || true
    fail 1 "sni_router.py exited at once (log $ROUTER_LOG)"
  fi
  say "SNI router pid $pid, log $ROUTER_LOG"
}

start_sni() {
  [ -n "$(proxy_url)" ] || fail 1 "the sni path needs HTTPS_PROXY in the environment"
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
  # sni_router.py reads HTTPS_PROXY once, at start. In relay mode it (and the
  # daemon) use the egress relay, which re-reads rotated credentials.
  if [ "$CRED_MODE" = relay ]; then
    ensure_relay
  fi
  ensure_router
  export PILOT_BIN="$DAEMON" PILOT_REGISTRY_TRUST="$TRUST" PILOT_REGISTRY_FINGERPRINT="$FINGERPRINT"
  if [ "$CRED_MODE" = relay ]; then
    relay_env
    launch "${RELAY_ENV[@]}" unshare -m bash "$SCRIPT_DIR/run-daemon.sh"
  else
    launch unshare -m bash "$SCRIPT_DIR/run-daemon.sh"
  fi
}

start_chosen() {
  local how="registry trust $TRUST"
  case "$CHOSEN" in native | direct)
    if [ -n "$TRANSPORT" ]; then
      how="-transport=$TRANSPORT ($TRANSPORT_WHY), $how"
    else
      how="transport from $TRANSPORT_WHY, $how"
    fi
    ;;
  esac
  if [ "$CRED_MODE" != none ]; then
    how="$how, proxy credentials: $CRED_MODE ($CRED_WHY)"
  fi
  say "pilot-daemon $VERSION_TAG: $CHOSEN path, $how"
  REFRESH=""
  case "$CRED_MODE" in
    cmd | static) explicit_proxy_url || REFRESH="$(effective_proxy_cmd)" ;;
  esac
  if [ "$CRED_MODE" != relay ] && [ -n "$(live_pid "$RELAY_PID_FILE" is_relay)" ]; then
    stop_relay # left over from a relay-mode start; this node does not use it
  fi
  case "$CHOSEN" in
    native) start_native ;;
    direct) start_direct ;;
    sni) start_sni ;;
  esac
}

# stop_daemon — stop the respawn loop and the daemon (validated pids only),
# then any other pilot-daemon still answering on the socket.
stop_daemon() {
  local pid
  pid="$(live_pid "$SUP_PID_FILE" is_supervisor)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_supervisor 15
    say "stopped respawn loop (pid $pid)"
    STOPPED=$((STOPPED + 1))
  fi
  pid="$(live_pid "$DAEMON_PID_FILE" is_daemon)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_daemon 10
    say "stopped pilot-daemon (pid $pid)"
    STOPPED=$((STOPPED + 1))
  fi
  rm -f "$SUP_PID_FILE" "$DAEMON_PID_FILE" "$SUP_PROXY_FILE"
  stop_unmanaged_daemon
}

# stop_unmanaged_daemon — a pilot-daemon pilot-up did not start (by hand, or
# `pilotctl daemon start` whose pid file is gone or holds "0") that still
# answers on $SOCKET: ask `pilotctl daemon stop` (it knows launchd, and finds
# the socket's owner with lsof), then stop the socket's owner found through
# /proc, which must look like pilot-daemon. Sets STOP_FAILED when it still
# answers afterwards.
stop_unmanaged_daemon() {
  local pid=""
  node_online || return 0
  if with_timeout 20 "$PILOTCTL" --json daemon stop < /dev/null > /dev/null 2>&1 && ! node_online; then
    say "stopped the pilot-daemon answering on $SOCKET (pilotctl daemon stop; not started by pilot-up)"
    STOPPED=$((STOPPED + 1))
    return 0
  fi
  pid="$(socket_owner_pid)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_daemon 10
    say "stopped pilot-daemon pid $pid (it answered on $SOCKET; not started by pilot-up)"
    STOPPED=$((STOPPED + 1))
  fi
  if node_online; then
    say "warning: a pilot-daemon still answers on $SOCKET and could not be stopped${pid:+ (pid $pid)}." \
      "  Stop it yourself (pilotctl daemon stop, or kill the process that owns $SOCKET), then rerun this." >&2
    STOP_FAILED=1
  fi
}

# stop_router — stop the SNI router from its pid file, and any other
# sni_router.py holding the router port (one started by hand).
stop_router() {
  local pid
  pid="$(live_pid "$ROUTER_PID_FILE" is_router)"
  if [ -n "$pid" ]; then
    stop_pid "$pid" is_router 5
    say "stopped SNI router (pid $pid)"
    STOPPED=$((STOPPED + 1))
  fi
  rm -f "$ROUTER_PID_FILE" "$ROUTER_PROXY_FILE"
  for pid in $(router_listener_pids); do
    stop_pid "$pid" is_router 5
    if kill -0 "$pid" 2>/dev/null && is_router "$pid"; then
      say "warning: could not stop sni_router.py pid $pid (listening on port ${ROUTER_LISTEN##*:}; not started by pilot-up)" >&2
      STOP_FAILED=1
    else
      say "stopped SNI router pid $pid (listening on port ${ROUTER_LISTEN##*:}; not started by pilot-up)"
      STOPPED=$((STOPPED + 1))
    fi
  done
}

stop_all() {
  stop_daemon
  stop_router
  stop_relay
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

# loop_gone — the respawn loop has exited: it removes pilot-up.pid on the way
# out, and a pid that is no longer alive counts too. Only for waiting: it
# signals nothing, so it does not need live_pid's command-line proof (which a
# sandbox without procfs or ps cannot give).
loop_gone() {
  local pid
  pid="$(read_pid "$SUP_PID_FILE")"
  [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null
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
    if loop_gone; then
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

# auth_rejected — stdin (a log) shows the proxy rejecting the credentials: the
# daemon's "proxy CONNECT <host:port>: 407 Proxy Authentication Required", the
# SNI router's "HTTP/1.1 407 ..." status line, or, in Muse, "malformed HTTP
# status code" (the signatures pilot-daemon's own proxy code reacts to). Never
# a bare 407: slog timestamps (time=...T02:27:46.407Z), durations, sizes and
# pilot-up's own "after 407s" contain one.
auth_rejected() {
  grep -Eiq 'Proxy Authentication Required|proxy CONNECT( [^ ]+)?: 407([^0-9]|$)|HTTP/[0-9.]+ 407([^0-9]|$)|malformed HTTP status code'
}

# since_marker FILE MARKER — FILE's lines after the last line matching the ERE
# MARKER: what the process started there has logged. Nothing when no line
# matches, since the log then belongs to a start pilot-up knows nothing about.
since_marker() {
  local n
  n="$(grep -anE -- "$2" "$1" 2>/dev/null | tail -n 1)" || true
  n="${n%%:*}"
  case "$n" in '' | *[!0-9]*) return 0 ;; esac
  tail -n "+$((n + 1))" "$1" 2>/dev/null || true
}

# ppid_of PID — PID's parent pid (empty when unknown).
ppid_of() {
  local p="" stat fields
  if [ -r "/proc/$1/stat" ]; then
    stat="$(cat "/proc/$1/stat" 2>/dev/null || true)"
    read -r -a fields <<< "${stat##*) }" || true
    p="${fields[1]:-}"
  else
    p="$(ps -o ppid= -p "$1" 2>/dev/null || true)"
  fi
  printf '%s' "${p//[[:space:]]/}"
}

# managed_daemon — the pid of the running pilot-daemon when pilot-up's live
# respawn loop started it: pilot.pid names a pilot-daemon whose parent is the
# loop in pilot-up.pid, and no other pilot-daemon holds a socket on $SOCKET
# (which one answers could not be told apart). Nothing otherwise: a node
# started by hand, by `pilotctl daemon start`, or by a service (the official
# macOS launchd agent also logs to ~/.pilot/daemon.log).
managed_daemon() {
  local sup pid owner
  sup="$(live_pid "$SUP_PID_FILE" is_supervisor)"
  [ -n "$sup" ] || return 0
  pid="$(live_pid "$DAEMON_PID_FILE" is_daemon)"
  [ -n "$pid" ] || return 0
  [ "$(ppid_of "$pid")" = "$sup" ] || return 0
  for owner in $(socket_owner_pids); do
    [ "$owner" = "$pid" ] || return 0
  done
  printf '%s' "$pid"
}

# recent_auth_rejects — the logs that show the proxy rejecting credentials
# since the running processes started: daemon.log after the respawn loop's
# last "starting" line, sni_router.log after the running router's start.
# Only called for a node managed_daemon recognises.
recent_auth_rejects() {
  local out=""
  if since_marker "$LOG" '^pilot-up: [0-9TZ:-]+ starting ' | auth_rejected; then out="$LOG"; fi
  if [ -n "$(live_pid "$ROUTER_PID_FILE" is_router)" ] \
    && since_marker "$ROUTER_LOG" 'SNI router listening on' | auth_rejected; then
    out="${out:+$out and }$ROUTER_LOG"
  fi
  printf '%s' "$out"
}

# proxy_recorded_current — every running piece pilot-up started (respawn loop,
# SNI router) recorded this shell's proxy settings. False when one recorded
# other settings, or when nothing running recorded any (a node started by
# hand or by an older pilot-up).
proxy_recorded_current() {
  local any=0
  if [ -n "$(live_pid "$SUP_PID_FILE" is_supervisor)" ]; then
    fp_matches "$SUP_PROXY_FILE" || return 1
    any=1
  fi
  if [ -n "$(live_pid "$ROUTER_PID_FILE" is_router)" ]; then
    fp_matches "$ROUTER_PROXY_FILE" || return 1
    any=1
  fi
  [ "$any" = 1 ]
}

# rotated_proxy_restart — the node answers, but it was started in static mode
# (or by an older pilot-up), so its processes keep the proxy credentials they
# started with. After Muse rotates them, open tunnels survive while every new
# connection gets a 407 ("node online, all apps broken"). When pilot-up's
# respawn loop runs the node, its logs show that since the last start, and
# this shell's proxy settings differ from the recorded ones, stop everything
# so that the start that follows uses this shell's settings (and cmd or relay
# mode where it can). Nodes in cmd or relay mode re-read the credentials, so
# a 407 there is not a reason to restart; a node pilot-up did not start is
# never stopped here (main prints a note). Returns 0 when it stopped the node.
rotated_proxy_restart() {
  local rejects
  [ -n "$(proxy_url)" ] || return 1
  [ -n "$(managed_daemon)" ] || return 1
  case "$(recorded "$SUP_PROXY_FILE" 3)" in cmd | relay | none) return 1 ;; esac
  rejects="$(recent_auth_rejects)"
  [ -n "$rejects" ] || return 1
  if proxy_recorded_current; then
    say "warning: the proxy rejects this node's new connections (407 in $rejects), and the node already uses this shell's HTTPS_PROXY: those credentials are wrong or have expired." \
      "  Get fresh ones (in Muse, from a new shell), then: bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh" >&2
    return 1
  fi
  say "the proxy rejects the credentials this node was started with (407 in $rejects), and this shell's HTTPS_PROXY differs (Muse rotates proxy credentials): restarting the node with the current ones"
  stop_all
  if [ "$STOP_FAILED" != 0 ]; then
    fail 1 "could not stop the running node, so it keeps the old credentials (see above)"
  fi
  return 0
}

# next_step — the first diagnostic to try, from what the logs say.
next_step() {
  local text relay="" by="pilot-daemon -proxy-cmd"
  text="$(new_log)$(tail -n 20 "$ROUTER_LOG" 2>/dev/null || true)"
  if [ "$CRED_MODE" = relay ]; then
    relay="$(tail -n 40 "$RELAY_LOG" 2>/dev/null || true)"
    by="the egress relay"
  fi
  if grep -Eq 'auto-selected.*transport=udp' <<< "$text"; then
    echo "-transport=auto settled on udp (its check through the proxy failed), and udp never uses the proxy: rerun with PILOT_UP_TRANSPORT=compat"
    return 0
  fi
  if grep -q 'rejected after re-reading' <<< "$relay"; then
    echo "the proxy rejected even the credentials the egress relay re-read from a fresh shell (407 in $RELAY_LOG): a new shell's HTTPS_PROXY must hold working ones (bash -c 'printf %s \"\$https_proxy\"'), or set PILOT_PROXY_CMD to a command that prints the current proxy URL"
    return 0
  fi
  if grep -q 'cred-refresh failed' <<< "$relay"; then
    echo "the egress relay could not read the proxy URL from a fresh shell (cred-refresh failed in $RELAY_LOG): bash -c 'printf %s \"\$https_proxy\"' must print it, or set PILOT_PROXY_CMD to a command that does"
    return 0
  fi
  if auth_rejected <<< "$text"; then
    case "$CRED_MODE" in
      cmd | relay)
        echo "the proxy rejected the credentials (407) although $by re-reads them from a fresh shell: a new shell's HTTPS_PROXY must hold working ones (bash -c 'printf %s \"\$https_proxy\"'), or set PILOT_PROXY_CMD to a command that prints the current proxy URL" ;;
      *)
        echo "the proxy rejected the credentials in HTTPS_PROXY (407): they are wrong, or expired (Meta Muse rotates them every few minutes). Rerun from a new shell, which has current ones; elsewhere, check the user:pass part of HTTPS_PROXY" ;;
    esac
    return 0
  fi
  case "$text" in
    *"$RELAY_LISTEN"*refused*)
      echo "nothing accepts connections on the egress relay's address $RELAY_LISTEN: rerun pilot-up.sh, which restarts the relay (log $RELAY_LOG)" ;;
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
    *"502 Bad Gateway"* | *"503 Service Unavailable"* | *"504 Gateway Time"*)
      echo "the proxy took the credentials but could not reach the Pilot host (502/503/504): an outage on the proxy's side or at pilotprotocol.network; rerun later" ;;
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
  if [ "$CRED_MODE" = relay ]; then
    echo "--- last lines of $RELAY_LOG ---" >&2
    tail -n 5 "$RELAY_LOG" 2>/dev/null | redact >&2 || true
  fi
  echo "---" >&2
  fail 1 "next step: $(next_step)" \
    "then: bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh" \
    "notes: $TROUBLESHOOTING"
}

# report_online MESSAGE [CRED_MODE] — the node answers: print where, which
# daemon version is actually running (it can differ from the file on disk
# after an upgrade that did not restart the node), and how it gets current
# proxy credentials.
report_online() {
  local disk running creds
  say "$1"
  printf '  %-8s %s\n' \
    address "${NODE_ADDR:-unknown}${NODE_ID:+ (node $NODE_ID)}" \
    daemon "running ${NODE_VERSION:-(version not reported)}" \
    log "$LOG" \
    check "$PILOTCTL --json info" \
    stop "bash $SCRIPT_DIR/pilot-up.sh --stop" \
    restart "rerun bash $SCRIPT_DIR/pilot-up.sh after every VM restart"
  creds="$(creds_desc "${2:-}")"
  if [ -n "$creds" ]; then printf '  %-8s %s\n' proxy "credentials $creds"; fi
  disk="$(version_token "$VERSION")"
  running="$(version_token "$NODE_VERSION")"
  if [ -n "$disk" ] && [ -n "$running" ] && [ "$disk" != "$running" ]; then
    say "note: the running daemon is v$running but $DAEMON is v$disk; restart it to switch:" \
      "  bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh"
  fi
}

# heal_managed — an online node pilot-up runs still has what it was started
# with: the egress relay (relay mode) and the SNI router (sni path). One that
# died is started again; the daemon keeps running (its open tunnels, and the
# node's registration, survive).
heal_managed() {
  local mode path
  mode="$(recorded "$SUP_PROXY_FILE" 3)"
  path="$(recorded "$SUP_PROXY_FILE" 4)"
  if [ "$mode" = relay ]; then ensure_relay quiet; fi
  if [ "$path" = sni ] && [ -z "$(live_pid "$ROUTER_PID_FILE" is_router)" ]; then
    say "the SNI router this node uses is not running: starting it"
    CRED_MODE="$mode"
    ensure_router
  fi
}

main() {
  case "${1:-}" in
    '' | --stop) ;;
    -h | --help)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]:-$0}"
      exit 0
      ;;
    *) fail 2 "unknown argument: $1 (try --help)" ;;
  esac
  SOCKET="${PILOT_SOCKET:-$(config_value socket)}"
  SOCKET="${SOCKET:-/tmp/pilot.sock}"
  export PILOT_SOCKET="$SOCKET"
  if [ "${1:-}" = --stop ]; then
    stop_all
    if [ "$STOP_FAILED" != 0 ]; then exit 1; fi
    if [ "$STOPPED" = 0 ]; then
      say "nothing to stop: no respawn loop, pilot-daemon, SNI router or egress relay of this node is running"
    fi
    exit 0
  fi
  case "$MODE" in auto | native | direct | sni) ;; *) fail 2 "PILOT_UP_MODE must be auto, native, direct or sni (got '$MODE')" ;; esac
  case "$WAIT" in '' | *[!0-9]*) fail 2 "PILOT_UP_WAIT must be a number of seconds (got '$WAIT')" ;; esac
  case "$TRUST" in system | pinned) ;; *) fail 2 "PILOT_REGISTRY_TRUST must be system or pinned (got '$TRUST')" ;; esac
  case "$TRANSPORT_WANT" in '' | compat | auto | udp) ;; *) fail 2 "PILOT_UP_TRANSPORT must be compat, auto or udp (got '$TRANSPORT_WANT')" ;; esac
  if ! [[ $FINGERPRINT =~ ^[0-9a-fA-F]{64}$ ]]; then
    fail 2 "PILOT_REGISTRY_FINGERPRINT must be 64 hex characters (the registry leaf SHA-256; fetch snippet in $TROUBLESHOOTING)"
  fi
  if [ ! -x "$DAEMON" ] || [ ! -x "$PILOTCTL" ]; then
    fail 2 "pilotctl and pilot-daemon not found in $BIN_DIR" \
      "install them: curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash"
  fi
  mkdir -p "$PILOT_DIR"
  VERSION="$(daemon_version)"
  VERSION_TAG="$(version_token "$VERSION")"
  VERSION_TAG="${VERSION_TAG:+v$VERSION_TAG}"
  VERSION_TAG="${VERSION_TAG:-${VERSION:-unknown version}}"
  case "$CREDS_WANT" in auto | cmd | relay | static) ;; *) fail 2 "PILOT_UP_CREDS must be auto, cmd, relay or static (got '$CREDS_WANT')" ;; esac
  DAEMON_HELP="$("$DAEMON" -h 2>&1 < /dev/null || true)"
  CHOSEN="$MODE"
  if [ "$CHOSEN" = "auto" ]; then
    if supports_proxy_flag; then
      CHOSEN="native"
    elif [ -z "$(proxy_url)" ]; then
      CHOSEN="direct"
    else
      CHOSEN="sni"
    fi
  fi
  pick_creds

  if node_online && ! rotated_proxy_restart; then
    local online_mode=""
    if [ -n "$(managed_daemon)" ]; then
      online_mode="$(recorded "$SUP_PROXY_FILE" 3)"
      heal_managed
    fi
    report_online "node already online" "$online_mode"
    if [ -n "$(proxy_url)" ] && ! proxy_recorded_current; then
      if [ -z "$(managed_daemon)" ]; then
        say "note: this node was not started by pilot-up, so pilot-up never restarts it on its own. Unless it re-reads proxy credentials itself (pilot-daemon -proxy-cmd), new Pilot connections fail with 407 once the proxy rotates them." \
          "  Then restart it the way it was started, or replace it with one pilot-up runs: bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh"
      elif [ "$online_mode" = cmd ] || [ "$online_mode" = relay ]; then
        say "note: this shell's proxy settings differ from the ones the node started with (not just the credentials, which it re-reads); restart it to switch:" \
          "  bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh"
      else
        say "note: this shell's HTTPS_PROXY differs from the one the node started with, and the node does not re-read it." \
          "  If new Pilot connections fail with 407, restart it: bash $SCRIPT_DIR/pilot-up.sh --stop && bash $SCRIPT_DIR/pilot-up.sh"
      fi
    fi
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
  drop_stale "$SUP_PID_FILE" is_supervisor "$SUP_PROXY_FILE"
  drop_stale "$DAEMON_PID_FILE" is_daemon
  drop_stale "$ROUTER_PID_FILE" is_router "$ROUTER_PROXY_FILE"
  drop_stale "$RELAY_PID_FILE" is_relay "$RELAY_PROXY_FILE"
  case "$CHOSEN" in native | direct) pick_transport ;; esac

  sup="$(live_pid "$SUP_PID_FILE" is_supervisor)"
  if [ -n "$sup" ] && fp_matches "$SUP_PROXY_FILE" "$CRED_MODE" "$CHOSEN"; then
    say "respawn loop already running (pid $sup); waiting for it instead of starting another"
    ADOPTED="$sup"
    LOG_OFFSET="$(file_size "$LOG")"
    # What it relies on may have died since (the loop only restarts the
    # daemon): the relay, and on the sni path the router.
    if [ "$CRED_MODE" = relay ]; then ensure_relay quiet; fi
    if [ "$CHOSEN" = sni ]; then ensure_router; fi
  else
    if [ -n "$sup" ]; then
      # Its daemon (or the SNI router) keeps the proxy settings it started
      # with; waiting for it would reuse credentials that may have rotated.
      say "restarting respawn loop pid $sup: it was started with different proxy settings (for example credentials that have rotated since)"
      stop_daemon
    fi
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
      report_online "node online (respawn loop pid $ADOPTED was already running)" "$CRED_MODE"
    else
      report_online "node online via the $CHOSEN path (registry trust $TRUST)" "$CRED_MODE"
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

# Run main unless this file is being sourced (tests source it for its
# functions).
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main "$@"
fi
