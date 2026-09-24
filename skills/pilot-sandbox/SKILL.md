---
name: pilot-sandbox
description: >
  Get a Pilot Protocol node online in a network-restricted agent sandbox (Meta
  Muse and similar VMs: no outbound UDP, poisoned DNS, egress only via an
  authenticating HTTPS proxy whose credentials rotate). scripts/pilot-up.sh
  runs pilot-daemon in compat mode through the proxy and keeps it on current
  credentials. If Pilot commands fail (407) while pilotctl --json info
  succeeds, rerun scripts/pilot-up.sh from a fresh shell.

  Use this skill when:
  1. Pilot commands fail (407, connection errors) while pilotctl --json info
     succeeds
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
  (util-linux), and root or CAP_SYS_ADMIN. Rotating credentials: python3 for
  scripts/egress_relay.py unless pilot-daemon has -proxy-cmd.
metadata:
  author: vulture-labs
  version: "1.3"
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
authenticating egress proxy (first done in Meta Muse's VM on 2026-09-23).

## Constraints (verify before assuming they changed)
- Outbound UDP is blocked, so the default transport cannot work.
- `/etc/resolv.conf` and `/etc/hosts` are read-only; Pilot names resolve to
  `198.18.x.x`. Nothing may resolve them locally.
- `HTTPS_PROXY` (credentials in the URL) allows `CONNECT host:443` only, by
  hostname. Anything that bypasses it is killed by the network guard.
- Pilot's `registry.` (TLS) and `beacon.` (WSS) share `:443`, SNI-routed.
- No systemd. Nothing restarts the daemon after a VM restart.

## One command
```bash
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash
```
Installs this skill, `pilotctl` and `pilot-protocol`, plus the binaries in
`~/.pilot/bin` if missing (official installer), then runs `scripts/pilot-up.sh`.

## (Re)start after a VM restart
```bash
bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh
```
Returns: exit 0 with the node address once registered (at once if it already
is); exit 1 with the log tail and the next diagnostic step; exit 3 when the
only viable path needs root (it prints what to do). `pilot-up.sh --stop` stops
everything, including a daemon or router it did not start.

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

## Rotating proxy credentials (407 while `pilotctl --json info` works)
Muse rotates them every few minutes; a process keeps the ones it started with,
so new connections get `407 Proxy Authentication Required` (or `malformed HTTP
status code`). A fresh shell has current ones, and `pilot-up.sh` makes the node
re-read them there (it prints the mode; `PILOT_UP_CREDS` forces one):
- `cmd`: `pilot-daemon -h` lists `-proxy-cmd`. The daemon re-runs
  `bash -c 'printf %s "${https_proxy:-$HTTPS_PROXY}"'` (or `PILOT_PROXY_CMD`,
  or `proxy_cmd` in `config.json`) every 60s and after a 407.
- `relay`: older daemons. `scripts/egress_relay.py` on `127.0.0.1:3128`
  (`PILOT_RELAY_LISTEN`) stamps fresh credentials on every connection; the
  daemon and SNI router use it as their proxy and hold no credentials.
- The respawn loop re-reads them before every daemon (re)start.
If 407s persist, rerun `scripts/pilot-up.sh` from a fresh shell: it restarts a
relay or router that died, and a node started without this handling.

## Fast path: native proxy (pilot-daemon with -proxy)
A foreground debug run of what `pilot-up.sh` starts (use `pilot-up.sh` for real):
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
  `pilot-up.sh` adds `-proxy-cmd` when the daemon has it (section above).
- The proxy is asked to `CONNECT` by hostname, so the poisoned DNS never
  matters; TLS stays end to end and proxy URLs are logged redacted.

## Fallback: SNI router (older daemons, root)
For a `pilot-daemon` without `-proxy`. `pilot-up.sh` does all of this when it
runs as root; the pieces, under `scripts/`, use `egress_relay.py` as proxy:

1. `sni_router.py` listens on `127.0.0.1:443`, reads each ClientHello's SNI
   without modifying it, opens a proxy `CONNECT` tunnel to the matching host,
   replays the original bytes and pipes. TLS stays end to end.
2. `run-daemon.sh` bind-mounts `hosts.template` (the two Pilot hostnames at
   `127.0.0.1`) over `/etc/hosts` inside a private mount namespace
   (`unshare -m`) and execs `pilot-daemon` in compat mode. Only the daemon
   sees the override.

To debug by hand (root, skill directory; use `pilot-up.sh` for real):
```bash
python3 scripts/egress_relay.py                                      # shell 1
HTTPS_PROXY=http://127.0.0.1:3128 python3 scripts/sni_router.py      # shell 2
HTTPS_PROXY=http://127.0.0.1:3128 unshare -m ./scripts/run-daemon.sh # shell 3
```
Returns: `routed SNI=...` lines from the router, then `daemon registered`
from the daemon. Router lines without registration mean TLS trust failed.

## Verify end to end
```bash
pilotctl --json info                                   # node identity + address
pilotctl --json trusted list                           # directory fetched over the network
pilotctl --json ping 0:0000.0000.660F --count 2 --timeout 30s   # trust handshake + relay ping
```
Returns: node ID and address; the service-agent directory; round-trip times
through the beacon relay. All three succeeding means both paths work.

## TLS trust: `system` first, `pinned` as fallback
`pilot-up.sh` starts with `-registry-trust=system`. On a registry x509 error it
restarts the daemon once with `-registry-trust=pinned` and the bundled pin
(`c1f958f6...`, valid until 2026-12-16), and says so. With no CA bundle where
Go looks, it sets `SSL_CERT_FILE` to one on the box (the beacon WSS cannot be
pinned). To choose yourself (`system` means no retry):
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
pilotctl --json send-message pilot-mom --data 'current BTC price in USD' --wait | jq -e -r '.data.reply.data // .data.data // empty'
```
Returns: `node online` with the address, then pilot-mom's reply body. A
non-zero exit means no reply arrived: retry, never read an older inbox file.

## Dependencies
- `pilot-protocol` skill (core commands) and `pilotctl` entrypoint skill
- `pilotctl` and `pilot-daemon` in `~/.pilot/bin` (`muse/install.sh`, the
  official installer, or `pilotprotocol-mcp`)
- `bash`; `HTTPS_PROXY` in the environment, allowing `CONNECT` to `:443`
- `python3` (stdlib) for relay mode; the sni fallback also needs `unshare`
  (util-linux) and root or `CAP_SYS_ADMIN`

## References
- `references/troubleshooting.md`: symptoms (407, refused `CONNECT`,
  `NO_PROXY`, x509), dead ends already explored, fingerprint re-fetch.
- https://pilotprotocol.network/docs/firewalls: compat mode without a proxy.
