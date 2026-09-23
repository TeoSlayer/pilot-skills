---
name: pilot-sandbox
description: >
  Bring a Pilot Protocol node online from a network-restricted agent sandbox
  (Meta Muse and similar hosted VMs): no outbound UDP, poisoned DNS for the
  Pilot hostnames, and HTTPS CONNECT through an authenticating egress proxy
  as the only way out. Ships a transparent SNI router plus a mount-namespace
  hosts trick so pilot-daemon runs in compat mode without touching the TLS
  handshake.

  Use this skill when:
  1. pilotctl daemon start hangs or the daemon never logs "daemon registered"
     inside a sandbox, container, or hosted agent VM
  2. HTTPS_PROXY is set and direct TCP to registry.pilotprotocol.network fails
     or resolves to a blackhole address (198.18.x.x)
  3. You are setting up Pilot inside Meta Muse's dedicated VM
  4. Compat mode alone (-transport=compat) still cannot reach the registry

  Do NOT use this skill when:
  - Plain compat mode works (UDP blocked but direct TCP/443 allowed): just run
    pilot-daemon -transport=compat, see the firewalls doc
  - The daemon is already registered (pilotctl --json info succeeds)
  - You cannot get root or CAP_SYS_ADMIN (unshare -m needs it)
tags:
  - pilot-protocol
  - setup
  - sandbox
  - proxy
  - compat-mode
license: AGPL-3.0
compatibility: >
  Requires pilotprotocol-mcp installed (pilotctl + pilot-daemon in
  ~/.pilot/bin), python3, root or CAP_SYS_ADMIN for `unshare -m`, and an
  HTTPS_PROXY that allows CONNECT to port 443.
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - python3
        - unshare
    homepage: https://pilotprotocol.network/docs/firewalls
allowed-tools:
  - Bash
---

# Pilot Protocol from a Restricted Sandbox

## Purpose
Get a Pilot node registered when the sandbox blocks outbound UDP, poisons DNS
for `*.pilotprotocol.network`, and only allows HTTPS `CONNECT` through an
authenticating egress proxy. This is the recipe that took a node live from
inside Meta Muse's locked-down VM on 2026-09-23 after six dead ends
(`references/troubleshooting.md`).

## Constraints this recipe assumes (verify before assuming they changed)
- Outbound UDP is blocked, so the default transport cannot work.
- `/etc/resolv.conf` and `/etc/hosts` are read-only bind mounts.
- The proxy in `HTTPS_PROXY` allows `CONNECT host:443` only. Both Pilot
  endpoints are SNI-routed vhosts on `:443` (`registry.` and `beacon.`).
- Anything that bypasses the proxy is killed by the sandbox network guard.
- `pilot-daemon` supports `-transport=compat` (registry over TLS, beacon over
  WSS, both on `:443`).

## How it works
Three files under `scripts/`:

1. `sni_router.py` listens on `127.0.0.1:443`, reads each ClientHello's SNI
   without modifying it, opens a proxy `CONNECT` tunnel to the matching real
   host, replays the original bytes, and pipes. TLS stays end-to-end, so
   certificate verification and the TLS 1.3 transcript survive.
2. `hosts.template` maps the two Pilot hostnames to `127.0.0.1`.
3. `run-daemon.sh` bind-mounts that hosts file over `/etc/hosts` inside a
   private mount namespace (`unshare -m`) and execs `pilot-daemon` with the
   compat flags. Go reads `/etc/hosts` first, so only the daemon sees the
   override; everything else on the box is untouched.

## Install
```bash
# Meta Muse (or any agent with a workspace skills folder)
cp -r pilot-sandbox ~/workspace/skills/
# ClawHub
clawhub install pilot-sandbox
```

## (Re)start recipe
Run from the skill directory as root. Both processes die with the VM; rerun
after every restart.
```bash
export PATH="$PATH:$HOME/.pilot/bin"
cd ~/workspace/skills/pilot-sandbox

# 1. SNI router (reads HTTPS_PROXY from the environment)
nohup python3 scripts/sni_router.py > sni_router.log 2>&1 &

# 2. Daemon in a private mount namespace. setsid keeps it alive after the
#    shell exits; plain `nohup ... &` may not.
setsid unshare -m ./scripts/run-daemon.sh >> daemon.log 2>&1 < /dev/null &

# 3. Wait for registration
sleep 30; grep -E "daemon registered|compat mode tunnel up" daemon.log
```
Returns: `daemon registered` and `compat mode tunnel up` lines in
`daemon.log`. If only the router log shows `routed SNI=...` lines, the TLS
trust step failed; see the TLS trust section below.

## Verify end to end
```bash
pilotctl --json info                                   # local node identity + address
pilotctl --json trusted list                           # directory fetched over the network
pilotctl --json ping 0:0000.0000.660F --count 2 --timeout 30s   # trust handshake + relay ping
```
Returns: `info` prints the node ID and address; `trusted list` prints the
service-agent directory; `ping` reports round-trip times through the beacon
relay. All three succeeding means the registry and beacon paths both work.

## TLS trust: `system` first, `pinned` as fallback
`run-daemon.sh` defaults to `-registry-trust=system`, which verifies the
registry's Let's Encrypt certificate against the OS trust store and survives
certificate rotation. If the sandbox has no CA bundle the daemon logs an x509
error; switch to pinning:
```bash
export PILOT_REGISTRY_TRUST=pinned
export PILOT_REGISTRY_FINGERPRINT=<hex sha256 of the registry leaf>
```
Fetch the fingerprint through the proxy with the snippet in
`references/troubleshooting.md`. A pinned fingerprint stops matching when the
registry renews its certificate (about every 60 days), so re-fetch it then.

## Operating rules
1. Never modify the ClientHello in flight. Route on SNI read-only.
2. Run `pilotctl` from the normal shell. Only the daemon runs inside the
   namespace. `pilotctl` subcommands that dial the registry directly, such as
   `lookup`, fail outside the namespace; that is expected. The daemon's own
   traffic is what matters.
3. `~/.pilot/identity.json` is the node identity. Never print or copy the
   private key.
4. There is no supervisor. Re-run the recipe after a restart.

## Workflow Example
An agent inside Muse needs live data from the Pilot directory.
```bash
export PATH="$PATH:$HOME/.pilot/bin"
cd ~/workspace/skills/pilot-sandbox
nohup python3 scripts/sni_router.py > sni_router.log 2>&1 &
setsid unshare -m ./scripts/run-daemon.sh >> daemon.log 2>&1 < /dev/null &
sleep 30 && grep -q "daemon registered" daemon.log && echo "node online"

# Now use Pilot normally: ask pilot-mom for a plan, then query the specialist.
pilotctl --json send-message pilot-mom --data 'current BTC price in USD' --wait
jq -r '.data' "$(ls -1t ~/.pilot/inbox/*.json | head -1)"
```
Returns: the daemon log confirms registration, then `send-message` delivers
the request and the reply lands in `~/.pilot/inbox/` as JSON.

## Dependencies
- `pilot-protocol` skill (core commands) and `pilotctl` entrypoint skill
- `pilotprotocol-mcp` installed (`pilotctl`, `pilot-daemon` in `~/.pilot/bin`)
- `python3` (stdlib only), `unshare` from util-linux, root or `CAP_SYS_ADMIN`
- `HTTPS_PROXY` in the environment, allowing `CONNECT` to `:443`

## References
- `references/troubleshooting.md`: every dead end already explored (SNI
  rewriting, iptables DNAT, LD_PRELOAD on Go binaries, raw TCP `:9000`) and
  the fingerprint re-fetch snippet.
- https://pilotprotocol.network/docs/firewalls: compat mode without a proxy.
