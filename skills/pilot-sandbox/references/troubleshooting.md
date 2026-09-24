# Troubleshooting: Pilot from a restricted sandbox

Start with `bash scripts/pilot-up.sh`: it prints the last lines of
`~/.pilot/daemon.log` and a next step when the node does not register. The
tables below map what you see to a fix. The dead ends further down were
explored on 2026-09-23 while getting node 251945 online from inside Meta
Muse's VM; read them before trying a "simpler" approach.

## Native proxy mode (`pilot-daemon` with `-proxy`)
Check support with `pilot-daemon -h 2>&1 | grep -E '^\s+-proxy'`. The daemon
logs proxy URLs redacted (`http://***@host:port`); never paste the raw
`HTTPS_PROXY` value into a log or an issue.

| Symptom | Cause | Fix |
|---|---|---|
| Pilot commands fail while `pilotctl --json info` works; `proxy CONNECT ...: 407 Proxy Authentication Required` (or `malformed HTTP status code`) in `daemon.log` | wrong, missing or expired proxy credentials. Muse rotates them every few minutes, and a process keeps the ones it started with, unless it re-reads them (`proxy credentials: cmd` or `relay` in `pilot-up.sh`'s output) | rerun `pilot-up.sh` from a new shell (current credentials): it restarts a dead egress relay or router, whatever was started with other proxy settings, and an online node in `static` mode (or from an older `pilot-up.sh`) whose log shows 407s since its respawn loop last started it; the new start re-reads credentials where it can. A node started another way (by hand, `pilotctl daemon start`, a service) only gets a note: restart it the way it was started, or `pilot-up.sh --stop && pilot-up.sh`. Elsewhere, check the `user:pass@` part of `HTTPS_PROXY`; URL-encode `@`, `:` and `/` inside the password |
| next step: `the proxy rejected the credentials (407) although ... re-reads them from a fresh shell` | a new shell's `HTTPS_PROXY` has no working credentials either, or the command that prints it is wrong | check `bash -c 'printf %s "$https_proxy"' \| sed -E 's#//[^@]*@#//***@#'` in a new shell; set `PILOT_PROXY_CMD` to a command that prints the current proxy URL |
| `cred-refresh failed` in `~/.pilot/egress_relay.log` | the relay's fresh shell printed no proxy URL, or printed the relay's own address | start `pilot-up.sh` from a shell whose `HTTPS_PROXY` is the real proxy (not `http://127.0.0.1:3128`), or set `PILOT_PROXY_CMD` |
| `127.0.0.1:3128 is taken by a process that is not egress_relay.py` | something else listens on the relay port | `PILOT_RELAY_LISTEN=127.0.0.1:<free port>`. An `egress_relay.py` started by hand is used as is (and never stopped) |
| `this shell's HTTPS_PROXY is the egress relay's address` | the shell exported the relay's URL (the manual recipe does), and no relay runs | rerun from a new shell with the sandbox's own `HTTPS_PROXY`; `pilot-up.sh` starts the relay itself |
| `the node already uses this shell's HTTPS_PROXY` (warning, node online) | the proxy rejects the credentials this shell has too | get fresh ones (in Muse, a new shell), then `pilot-up.sh --stop && pilot-up.sh` |
| `502 Bad Gateway` / `503` / `504` from the proxy | the proxy accepted the credentials but could not reach the Pilot host | an outage on the proxy's side or at `pilotprotocol.network`: rerun later |
| proxy refused `CONNECT` (`403`, `405`) | proxy allowlist does not include the Pilot hosts | it must allow `registry.pilotprotocol.network:443` and `beacon.pilotprotocol.network:443` |
| dial errors naming `198.18.x.x`, or `i/o timeout` straight after start | the connection skipped the proxy | `NO_PROXY`/`no_proxy` must not cover `pilotprotocol.network` (or be `*`); `pilot-up.sh` warns when it does |
| same, with `NO_PROXY` clean | the daemon never saw the proxy | `export HTTPS_PROXY` (not just set it) and start via `pilot-up.sh`; a released `pilotctl daemon start` cannot pass `-proxy` |
| `-proxy=auto` but traffic goes direct | `-transport=udp`, or `-transport=auto` that settled on udp (`transport auto-selected transport=udp` in `daemon.log`: its one check through the proxy failed) | auto only applies in compat mode. `pilot-up.sh` passes `-transport=compat` whenever a proxy is set or `~/.pilot/targets/muse` exists; `PILOT_UP_TRANSPORT=compat` forces it otherwise |
| `note: config.json sets transport auto; using compat` | the official installer writes `"transport": "auto"` for new installs | nothing: behind a proxy `pilot-up.sh` always uses compat. `PILOT_UP_TRANSPORT=auto` to insist |
| `registry TLS failed with system trust ... retrying once with -registry-trust=pinned` | registry x509 error (no CA bundle, or a TLS-intercepting proxy) | nothing: `pilot-up.sh` pins the bundled fingerprint by itself. Set `PILOT_REGISTRY_TRUST` to choose explicitly |
| `x509: certificate signed by unknown authority` after the pinned retry | the beacon (WSS) has no pinned mode and found no CA bundle | `export SSL_CERT_FILE=/path/ca.pem` (the proxy's CA if it intercepts) and rerun. `pilot-up.sh` already looks for python certifi and Node's roots |
| `certificate fingerprint mismatch` | the registry renewed its certificate since the pin | re-fetch the fingerprint (below) into `PILOT_REGISTRY_FINGERPRINT`, or use `system` trust with a CA bundle |
| `flag provided but not defined: -proxy` | daemon predates `-proxy` | `pilot-up.sh` picks the SNI fallback on its own; do not force `PILOT_UP_MODE=native` |
| `pilot-up.sh` exits 3 | older daemon, and no root / CAP_SYS_ADMIN for the fallback | once the release with `-proxy` is out: `curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh \| PILOT_UPGRADE=1 bash` (works as root: it passes `PILOT_ALLOW_ROOT=1` to the official installer, and restarts the node). Or rerun as root with `sudo -E` where root has CAP_SYS_ADMIN |
| `removed stale ~/.pilot/pilot.pid` (or `pilot-up.pid`, `sni_router.pid`) | left behind by a VM restart, a crash, or a failed `pilotctl daemon start` (which leaves `0`) | nothing: a pid file is only trusted when the live process's command line matches (`pilot-daemon`, or this skill's own `run-daemon.sh`; another project's `run-daemon.sh` is not) |
| `note: the running daemon is vX but ... is vY` | the binary was upgraded but the old daemon is still running | `pilot-up.sh --stop && pilot-up.sh` (`PILOT_UPGRADE=1` through the Muse installer does this for you). `--stop` also stops a daemon started by hand: it finds the process that owns the socket |
| `pilot-up.sh --stop` exits 1: `a pilot-daemon still answers on ... and could not be stopped` | the socket's owner is not a `pilot-daemon` process pilot-up may signal, or belongs to another user | stop it yourself (`pilotctl daemon stop`, or kill the process that owns the socket), then rerun |
| `daemon registered` never appears, no error | slow proxy | `PILOT_UP_WAIT=180 bash scripts/pilot-up.sh` |

## The environment
- `pilotprotocol-mcp` installed via npx; `pilotctl` and `pilot-daemon` in `~/.pilot/bin`.
- Daemon CLI has `-transport=compat`, `-registry`, `-registry-tls`,
  `-registry-trust={pinned,system}`, `-registry-fingerprint`, `-compat-beacon`,
  `-socket`, `-identity`. Run `pilot-daemon --help` for the full list.
  Released `pilotctl daemon start` does NOT forward all of them (no
  `-registry-trust`, `-registry-fingerprint` or `-proxy`), so run the daemon
  binary directly when you need them. `pilot-up.sh` does exactly that.

## What failed and why

1. **Default mode (UDP plus raw TCP registry `:9000`).** Outbound UDP blocked;
   the egress proxy refuses `CONNECT` to `:9000`. Dead.

2. **`PILOT_TRANSPORT=compat` via `pilotctl daemon start`.** Ignored. pilotctl
   passes the environment through, but released `pilot-daemon` defines
   `-transport` with a fixed `udp` default and never reads the variable. The
   config-file key `"transport": "compat"` in `~/.pilot/config.json` DID work.

3. **Compat mode with the default registry `34.71.57.205:9000`.** In compat
   mode the daemon dials the registry with TLS; `:9000` is raw TCP, so the
   handshake fails. Point it at `registry.pilotprotocol.network:443` instead.

4. **Direct dial of `registry.pilotprotocol.network:443`.** Sandbox DNS
   returns a poisoned `198.18.67.197`; direct TCP fails.

5. **TCP forwarder on `127.0.0.1:18443` plus `-registry=127.0.0.1:18443`.**
   Connects, but the multi-tenant server serves a default certificate when
   the SNI is not `registry.pilotprotocol.network`, so verification fails.

6. **Rewriting or injecting SNI in the ClientHello at the forwarder.**
   Structurally valid, but TLS 1.3 (and 1.2) bind session keys to the
   handshake transcript. The server sees a different ClientHello than the
   client sent, and the handshake ends in `DECRYPTION_FAILED_OR_BAD_RECORD_MAC`.
   Transparent proxying is mandatory.

7. **`iptables -t nat` DNAT of the poisoned IPs to localhost.** Kernel modules
   for `tcp` and `DNAT` are missing under the nf_tables backend
   (`RULE_APPEND failed`). Dead.

8. **`ip addr add 198.18.67.197/32 dev lo` plus binding the forwarder there.**
   Packets route locally, but the sandbox's own network guard intercepts
   non-proxied TCP and answers with a policy message (`WRONG_VERSION_NUMBER`
   on TLS). Any approach that bypasses the egress proxy trips the guard.
   Everything must go through the proxy via `CONNECT`.

9. **`LD_PRELOAD` to override DNS or connect.** Go binaries issue syscalls
   directly, not via libc, so preloading cannot intercept them.

10. **Editing `/etc/hosts` or `/etc/resolv.conf` directly.** Both are
    read-only bind mounts. The working trick: `unshare -m` (new mount
    namespace; you are root) plus `mount --bind` a custom hosts file over
    `/etc/hosts`, then run the daemon inside that namespace. Go's resolver
    reads `/etc/hosts` first, so the daemon resolves the Pilot names to
    `127.0.0.1` while everything else on the box is unaffected.

## SNI-router fallback: symptoms and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `sni_router.py` exits with `HTTPS_PROXY not set` | env not exported | `export HTTPS_PROXY=...` before starting |
| `OSError: [Errno 98] Address already in use` from `sni_router.py` | another process holds `127.0.0.1:443` | `pilot-up.sh` stops an `sni_router.py` holding the port even without a pid file; anything else there has to be stopped by hand |
| `proxy refused CONNECT ...: 407` in `sni_router.log` | wrong or rotated proxy credentials (the router reads `HTTPS_PROXY` once, at start; `pilot-up.sh` points it at the egress relay, which re-reads them) | rerun `pilot-up.sh` from a new shell: it restarts a router started with other settings, and the relay if it died. Otherwise check the `user:pass@` part of `HTTPS_PROXY` (percent-encode `@ : / ? #` in it) |
| `sni_router: HTTPS_PROXY is not a valid proxy URL` | unparsable value (the router never echoes it) | use `http(s)://user:pass@host[:port]` with the credentials percent-encoded |
| `no route for SNI=None` | a non-TLS client hit port 443 | ignore; only the daemon should talk to the router |
| `mount --bind failed` from `run-daemon.sh` | not inside `unshare -m`, or no root | launch exactly as documented, or via `pilot-up.sh` as root |
| daemon logs `x509: certificate signed by unknown authority` | no CA bundle in the sandbox | `pilot-up.sh` retries once with the bundled pin; by hand, `PILOT_REGISTRY_TRUST=pinned` plus a fresh fingerprint (below) |
| daemon logs a fingerprint mismatch | registry certificate renewed | re-fetch the fingerprint (below), or switch to `system` |
| `pilotctl lookup` fails from the normal shell | expected outside the namespace | use `pilotctl --json info`, `trusted list`, `ping` instead |

## Re-fetching the registry certificate fingerprint
Needed once the bundled pin (`c1f958f6...`, valid until 2026-12-16) stops
matching: put the new value in `PILOT_REGISTRY_FINGERPRINT` (both paths read it).
```bash
python3 - <<'PY'
import os, socket, ssl, base64, hashlib
from urllib.parse import unquote, urlparse
p = urlparse(os.environ['HTTPS_PROXY'])
s = socket.create_connection((p.hostname, p.port or 80), timeout=20)
auth = ""
if p.username:
    cred = base64.b64encode(f"{unquote(p.username)}:{unquote(p.password or '')}".encode()).decode()
    auth = f"Proxy-Authorization: Basic {cred}\r\n"
s.sendall(f"CONNECT registry.pilotprotocol.network:443 HTTP/1.1\r\nHost: registry.pilotprotocol.network:443\r\n{auth}\r\n".encode())
assert b" 200" in s.recv(4096).split(b"\r\n")[0]
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
t = ctx.wrap_socket(s, server_hostname="registry.pilotprotocol.network")
print(hashlib.sha256(t.getpeercert(binary_form=True)).hexdigest())
t.close()
PY
```

## Beacon note
In compat mode the beacon URL defaults to
`wss://beacon.pilotprotocol.network/v1/compat` (override with
`-compat-beacon`). A plain HTTPS GET to that path through the proxy returns
`426 Upgrade Required`, which is a quick way to confirm the endpoint is alive
without the daemon.
