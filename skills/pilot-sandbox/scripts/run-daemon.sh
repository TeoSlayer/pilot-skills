#!/bin/bash
# run-daemon.sh — start pilot-daemon in compat mode inside a private mount
# namespace whose /etc/hosts points the Pilot TLS hostnames at the local SNI
# router (scripts/sni_router.py).
#
# pilot-up.sh launches it for you when the installed pilot-daemon predates the
# -proxy flag. By hand, launch it ONLY like this (root or CAP_SYS_ADMIN
# required for unshare -m):
#
#   setsid unshare -m ./scripts/run-daemon.sh >> ~/.pilot/daemon.log 2>&1 < /dev/null &
#
# Environment (all optional):
#   PILOT_REGISTRY_TRUST        system (default) | pinned
#   PILOT_REGISTRY_FINGERPRINT  hex SHA-256 of the registry leaf cert; only
#                               used when PILOT_REGISTRY_TRUST=pinned. See
#                               references/troubleshooting.md to re-fetch it.
#   PILOT_SOCKET                Unix socket path (default /tmp/pilot.sock)
#   PILOT_BIN                   pilot-daemon binary (default ~/.pilot/bin/pilot-daemon)
#   PILOT_HOSTNAME              node hostname (-hostname)
#
# `system` verifies the registry's Let's Encrypt certificate against the OS
# trust store and survives certificate rotation. `pinned` is the fallback for
# sandboxes with no CA bundle; it stops working when the registry renews its
# certificate (roughly every 60 days), at which point re-fetch the fingerprint.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTS_FILE="$SCRIPT_DIR/hosts"
DAEMON="${PILOT_BIN:-$HOME/.pilot/bin/pilot-daemon}"
SOCKET="${PILOT_SOCKET:-/tmp/pilot.sock}"
TRUST="${PILOT_REGISTRY_TRUST:-system}"
# Fingerprint of the registry.pilotprotocol.network leaf observed 2026-09-23
# (valid until 2026-12-16). Override with PILOT_REGISTRY_FINGERPRINT.
FINGERPRINT="${PILOT_REGISTRY_FINGERPRINT:-c1f958f6bcff667cf6a08d5066cc031a9086115a7667835877ca62a3019b3da9}"

[ -x "$DAEMON" ] || { echo "run-daemon: $DAEMON not found or not executable" >&2; exit 1; }
[ -f "$HOSTS_FILE" ] || cp "$SCRIPT_DIR/hosts.template" "$HOSTS_FILE"

# Prove we are in a private mount namespace: the bind mount must not leak.
if ! mount --bind "$HOSTS_FILE" /etc/hosts 2>/dev/null; then
  echo "run-daemon: mount --bind failed. Launch via: unshare -m $0 (needs root/CAP_SYS_ADMIN)" >&2
  exit 1
fi

EXTRA_ARGS=(-registry-trust="$TRUST")
[ "$TRUST" = "pinned" ] && EXTRA_ARGS+=(-registry-fingerprint="$FINGERPRINT")
[ -f "$HOME/.pilot/config.json" ] && EXTRA_ARGS+=(-config="$HOME/.pilot/config.json")
[ -n "${PILOT_HOSTNAME:-}" ] && EXTRA_ARGS+=(-hostname="$PILOT_HOSTNAME")

rm -f "$SOCKET"
exec "$DAEMON" \
  -transport=compat \
  -registry=registry.pilotprotocol.network:443 \
  -registry-tls \
  "${EXTRA_ARGS[@]}" \
  -compat-beacon=wss://beacon.pilotprotocol.network/v1/compat \
  -socket="$SOCKET" \
  -identity="$HOME/.pilot/identity.json"
