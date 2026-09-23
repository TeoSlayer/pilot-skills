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
| `407` / `Proxy Authentication Required` in `daemon.log` | wrong or missing proxy credentials | check the `user:pass@` part of `HTTPS_PROXY`; URL-encode `@`, `:` and `/` inside the password |
| proxy refused `CONNECT` (`403`, `405`) | proxy allowlist does not include the Pilot hosts | it must allow `registry.pilotprotocol.network:443` and `beacon.pilotprotocol.network:443` |
| dial errors naming `198.18.x.x`, or `i/o timeout` straight after start | the connection skipped the proxy | `NO_PROXY`/`no_proxy` must not cover `pilotprotocol.network` (or be `*`); `pilot-up.sh` warns when it does |
| same, with `NO_PROXY` clean | the daemon never saw the proxy | `export HTTPS_PROXY` (not just set it); start via `pilot-up.sh`, not a released `pilotctl daemon start`, which scrubs the environment |
| `-proxy=auto` but traffic goes direct | `-transport=udp` | auto only applies in compat mode; pass `-transport=compat`, or an explicit `-proxy=http://...` |
| `x509: certificate signed by unknown authority` | no CA bundle, or a TLS-intercepting proxy | `SSL_CERT_FILE=/path/ca.pem` (the proxy's CA if it intercepts), or `PILOT_REGISTRY_TRUST=pinned` plus a fresh fingerprint (below) |
| `flag provided but not defined: -proxy` | daemon predates `-proxy` | `pilot-up.sh` picks the SNI fallback on its own; do not force `PILOT_UP_MODE=native` |
| `pilot-up.sh` exits 3 | older daemon, and no root / CAP_SYS_ADMIN for the fallback | upgrade Pilot once the release with `-proxy` is out, or rerun as root with `sudo -E` |
| `daemon registered` never appears, no error | slow proxy | `PILOT_UP_WAIT=180 bash scripts/pilot-up.sh` |

## The environment
- `pilotprotocol-mcp` installed via npx; `pilotctl` and `pilot-daemon` in `~/.pilot/bin`.
- Daemon CLI has `-transport=compat`, `-registry`, `-registry-tls`,
  `-registry-trust={pinned,system}`, `-registry-fingerprint`, `-compat-beacon`,
  `-socket`, `-identity`. Run `pilot-daemon --help` for the full list.
  `pilotctl daemon start` does NOT forward all of them, and it scrubs the
  environment when forking, so run the daemon binary directly when you need
  env (such as `HTTPS_PROXY`) to propagate. `pilot-up.sh` does exactly that.

## What failed and why

1. **Default mode (UDP plus raw TCP registry `:9000`).** Outbound UDP blocked;
   the egress proxy refuses `CONNECT` to `:9000`. Dead.

2. **`PILOT_TRANSPORT=compat` via `pilotctl daemon start`.** The env var did
   not propagate (pilotctl scrubs env on fork). The config-file key
   `"transport": "compat"` in `~/.pilot/config.json` DID work.

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
| `proxy refused CONNECT ...: 407` in `sni_router.log` | wrong proxy credentials | check the `user:pass@` part of `HTTPS_PROXY` |
| `no route for SNI=None` | a non-TLS client hit port 443 | ignore; only the daemon should talk to the router |
| `mount --bind failed` from `run-daemon.sh` | not inside `unshare -m`, or no root | launch exactly as documented, or via `pilot-up.sh` as root |
| daemon logs `x509: certificate signed by unknown authority` | no CA bundle in the sandbox | `PILOT_REGISTRY_TRUST=pinned` plus a fresh fingerprint (below) |
| daemon logs a fingerprint mismatch | registry certificate renewed | re-fetch the fingerprint (below), or switch to `system` |
| `pilotctl lookup` fails from the normal shell | expected outside the namespace | use `pilotctl --json info`, `trusted list`, `ping` instead |

## Re-fetching the registry certificate fingerprint
Only needed with `PILOT_REGISTRY_TRUST=pinned` (both paths read it).
```bash
python3 - <<'PY'
import os, socket, ssl, base64, hashlib
from urllib.parse import urlparse
p = urlparse(os.environ['HTTPS_PROXY'])
s = socket.create_connection((p.hostname, p.port), timeout=20)
auth = ""
if p.username:
    cred = base64.b64encode(f"{p.username}:{p.password or ''}".encode()).decode()
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
