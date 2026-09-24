---
name: pilot-sandbox
description: >
  Get a Pilot Protocol node online in a network-restricted agent sandbox (Meta
  Muse and similar VMs: no outbound UDP, poisoned DNS, egress only via an
  authenticating HTTPS proxy). scripts/pilot-up.sh runs pilot-daemon in compat
  mode through the proxy, and restarts it after the proxy credentials rotate
  (Pilot commands then fail with 407 while pilotctl --json info works).

  Use this skill when:
  1. Pilot commands fail (407, connection errors) while pilotctl --json info
     succeeds: the proxy credentials rotated; rerun scripts/pilot-up.sh from a
     fresh shell
  2. Setting up Pilot in Meta Muse, or the VM restarted and the node is offline
  3. The daemon never logs "daemon registered" in a sandbox
  4. HTTPS_PROXY is set and registry.pilotprotocol.network resolves to
     198.18.x.x

  Do NOT use this skill when:
  - The daemon is registered AND Pilot commands work
  - Outbound UDP works: plain pilotctl daemon start is enough
  - No proxy and direct TCP/443 works: set "transport": "compat" in
    ~/.pilot/config.json
tags:
  - pilot-protocol
  - setup
  - sandbox
  - proxy
  - compat-mode
license: AGPL-3.0
compatibility: >
  Requires bash, pilotctl and pilot-daemon in ~/.pilot/bin (muse/install.sh
  installs both), and an HTTPS_PROXY that allows CONNECT to port 443. Fast
  path: a pilot-daemon with the -proxy flag (the release after v1.13.9;
  version TBD), no root. Fallback for older daemons: python3, unshare
  (util-linux), and root or CAP_SYS_ADMIN.
metadata:
  author: vulture-labs
  version: "1.2"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network/docs/firewalls
allowed-tools:
  - Bash
---

# Pilot Protocol from a Restricted Sandbox

## Purpose
Get a Pilot node registered when the sandbox blocks outbound UDP, poisons DNS
for `*.pilotprotocol.network`, and only allows HTTPS `CONNECT` through an
authenticating egress proxy. A node first went live inside Meta Muse's VM this
way on 2026-09-23, after the dead ends in `references/troubleshooting.md`.

## Constraints (verify before assuming they changed)
- Outbound UDP is blocked, so the default transport cannot work.
- `/etc/resolv.conf` and `/etc/hosts` are read-only; Pilot names resolve to
  `198.18.x.x`. Nothing may resolve them locally.
- `HTTPS_PROXY` (credentials in the URL) allows `CONNECT host:443` only, by
  hostname. Anything that bypasses it is killed by the network guard.
- Both Pilot endpoints are SNI-routed vhosts on `:443`: `registry.` (TLS) and
  `beacon.` (WSS). `pilot-daemon -transport=compat` uses exactly those.
- No systemd. Nothing restarts the daemon after a VM restart.

## One command
```bash
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash
```
Installs this skill, `pilotctl` and `pilot-protocol`, plus `pilotctl` and
`pilot-daemon` in `~/.pilot/bin` if missing (official installer; as root with
`PILOT_ALLOW_ROOT=1`), then runs `scripts/pilot-up.sh`. `curl` uses `HTTPS_PROXY`.

## (Re)start after a VM restart
```bash
bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh
```
Returns: exit 0 with the node address once `daemon registered` appears (or
at once if a registered daemon is already running); exit 1 with the log tail
and the next diagnostic step; exit 3 when the only viable path needs root
(it prints what to do). `pilot-up.sh --stop` stops everything, including a
daemon or router it did not start (exit 1 if one survives).

`pilot-up.sh` picks the first path that fits (force one with
`PILOT_UP_MODE=native|direct|sni`):

| Path | When | Needs |
|---|---|---|
| `native` | `pilot-daemon -h` lists `-proxy` | nothing extra, no root |
| `direct` | older daemon, no proxy in the environment | nothing extra |
| `sni` | older daemon behind a proxy | root + CAP_SYS_ADMIN, python3, unshare |

- The daemon runs under a respawn loop (`setsid`), logging to
  `~/.pilot/daemon.log`. Stale pid files are checked, then removed.
- Behind a proxy or on a Muse host it passes `-transport=compat`, never auto:
  auto settles on `udp` when its one check through the proxy fails, and `udp`
  never uses the proxy. `PILOT_UP_TRANSPORT=compat|auto|udp` overrides.

## Commands fail with 407 while `pilotctl --json info` works
Muse rotates proxy credentials every few minutes, and a running daemon keeps
the ones it started with: open tunnels survive, new connections get `407 Proxy
Authentication Required` (or `malformed HTTP status code`). Rerun
`scripts/pilot-up.sh` from a fresh shell: when it runs the node and the log
shows those 407s, it restarts the node with the current credentials. If it
says `node already online` with a note, run `pilot-up.sh --stop && pilot-up.sh`.

## Fast path: native proxy (pilot-daemon with -proxy)
What `pilot-up.sh` runs behind a proxy, in the foreground for debugging (start
the node for real with `pilot-up.sh`, so that `--stop` and reruns manage it):
```bash
export PATH="$PATH:$HOME/.pilot/bin"
pilot-daemon -h 2>&1 | grep -E '^\s+-proxy'        # supported?
pilot-daemon -transport=compat -proxy=auto \
  -registry registry.pilotprotocol.network:443 -registry-tls -registry-trust system \
  -identity ~/.pilot/identity.json -socket /tmp/pilot.sock
```
Returns: `daemon registered` and `compat mode tunnel up` in its output.

- `-proxy=auto` (default; env `PILOT_PROXY`): in compat mode every connection
  goes through `HTTPS_PROXY` (else `ALL_PROXY`), honouring `NO_PROXY`; `off`
  disables it; an explicit `http://[user:pass@]host:port` applies always.
- The proxy is asked to `CONNECT` by hostname, so the poisoned DNS never
  matters; TLS stays end to end and proxy URLs are logged redacted.
- Released `pilotctl daemon start` cannot pass `-proxy`, `-registry-trust` or
  `-registry-fingerprint`, so the daemon is run directly.

## Fallback: SNI router (older daemons, root)
For a `pilot-daemon` without `-proxy`. `pilot-up.sh` does all of this when it
runs as root; the pieces, under `scripts/`:

1. `sni_router.py` listens on `127.0.0.1:443`, reads each ClientHello's SNI
   without modifying it, opens a proxy `CONNECT` tunnel to the matching host,
   replays the original bytes and pipes. TLS stays end to end.
2. `hosts.template` maps the two Pilot hostnames to `127.0.0.1`.
3. `run-daemon.sh` bind-mounts that file over `/etc/hosts` inside a private
   mount namespace (`unshare -m`) and execs `pilot-daemon` in compat mode.
   Only the daemon sees the override.

To debug by hand (root, skill directory), run each piece in the foreground;
start the node for real with `pilot-up.sh`:
```bash
python3 scripts/sni_router.py              # shell 1
unshare -m ./scripts/run-daemon.sh         # shell 2
```
Returns: `routed SNI=...` lines from the router, then `daemon registered`
from the daemon. Router lines without registration mean TLS trust failed.

## Verify end to end
```bash
pilotctl --json info                                   # node identity + address
pilotctl --json trusted list                           # directory fetched over the network
pilotctl --json ping 0:0000.0000.660F --count 2 --timeout 30s   # trust handshake + relay ping
```
Returns: `info` prints the node ID and address; `trusted list` prints the
service-agent directory; `ping` reports round-trip times through the beacon
relay. All three succeeding means the registry and beacon paths both work.

## TLS trust: `system` first, `pinned` as fallback
`pilot-up.sh` starts with `-registry-trust=system` (Let's Encrypt; survives
rotation). On an x509 error for the registry it restarts the daemon once with
`-registry-trust=pinned` and the bundled fingerprint (`c1f958f6...`, the first
Muse node's pin, valid until 2026-12-16) and says so. With no CA bundle where
Go looks, it sets `SSL_CERT_FILE` to one found on the box, since the beacon
(WSS) cannot be pinned. To choose yourself (`system` means no retry):
```bash
export PILOT_REGISTRY_TRUST=pinned PILOT_REGISTRY_FINGERPRINT=<hex sha256>
```
Re-fetch it after each renewal (~60 days): `references/troubleshooting.md`.

## Operating rules
1. Never print `HTTPS_PROXY` or copy it into logs; it carries credentials.
2. Never modify a ClientHello in flight. Route on SNI read-only.
3. `~/.pilot/identity.json` is the node identity: never print or copy it.
4. With the `sni` path, only the daemon lives in the namespace. `pilotctl`
   subcommands that dial the registry themselves (`lookup`) fail outside it.

## Workflow Example
An agent inside Muse needs live data from the Pilot directory after a restart.
```bash
bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh || exit 1
export PATH="$PATH:$HOME/.pilot/bin"
pilotctl --json info
pilotctl --json send-message pilot-mom --data 'current BTC price in USD' --wait
jq -r '.data' "$(ls -1t ~/.pilot/inbox/*.json | head -1)"
```
Returns: `pilot-up.sh` prints `node online` with the address, then
`send-message` delivers the request and the reply lands in `~/.pilot/inbox/`.

## Dependencies
- `pilot-protocol` skill (core commands) and `pilotctl` entrypoint skill
- `pilotctl` and `pilot-daemon` in `~/.pilot/bin` (`muse/install.sh`, the
  official installer, or `pilotprotocol-mcp`)
- `bash`; `HTTPS_PROXY` in the environment, allowing `CONNECT` to `:443`
- Fallback only: `python3` (stdlib), `unshare` (util-linux), root or `CAP_SYS_ADMIN`

## References
- `references/troubleshooting.md`: symptoms (407, refused `CONNECT`,
  `NO_PROXY`, x509), dead ends already explored, fingerprint re-fetch.
- https://pilotprotocol.network/docs/firewalls: compat mode without a proxy.
