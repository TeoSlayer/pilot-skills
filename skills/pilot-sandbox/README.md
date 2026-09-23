# Sandbox

Bring a Pilot Protocol node online from a network-restricted agent sandbox: no outbound UDP, poisoned DNS, HTTPS-proxy-only egress. Built for Meta Muse's dedicated VM; works in any sandbox with the same shape. One idempotent script, `scripts/pilot-up.sh`, starts the node (and restarts it after a VM reboot): natively through the proxy when `pilot-daemon` has the `-proxy` flag, no root needed, or with the SNI-router recipe for older daemons.

**Category:** Discovery & Network | **License:** AGPL-3.0

## Install

Meta Muse, in one step (skills with the frontmatter Muse loads, `pilotctl` + `pilot-daemon`, node online):

```bash
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash
```

Any agent that loads skills from a workspace folder:

```bash
cp -r pilot-sandbox ~/workspace/skills/
bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh
```

ClawHub:

```bash
clawhub install pilot-sandbox
```

## What's inside

- `SKILL.md`: constraints, the fast path, the fallback, restart commands, verification
- `scripts/pilot-up.sh`: idempotent start/restart; picks the native `-proxy` path, plain compat, or the SNI fallback, runs the daemon under a respawn loop (always `-transport=compat` behind a proxy), retries once with the bundled registry pin on an x509 error, restarts whatever holds rotated proxy credentials, waits for registration and prints the next diagnostic step on failure; `--stop` also stops a daemon or router started by hand
- `scripts/sni_router.py`: fallback; transparent SNI router (reads the ClientHello SNI, tunnels through the proxy with `CONNECT`, never alters a byte)
- `scripts/run-daemon.sh`: fallback; launches `pilot-daemon` in compat mode inside a mount namespace with a custom hosts file
- `scripts/hosts.template`: fallback; the hosts overrides
- `references/troubleshooting.md`: native-mode symptoms, every dead end, the fingerprint snippet

## Requirements

- [Pilot Protocol](https://pilotprotocol.network) installed (`pilotctl` and `pilot-daemon` in `~/.pilot/bin`) and `bash`
- `HTTPS_PROXY` set, allowing `CONNECT` to port 443
- Fast path: a `pilot-daemon` with the `-proxy` flag (the release after v1.13.9; version TBD). No root.
- Fallback for older daemons: `python3` and `unshare` (util-linux); root or `CAP_SYS_ADMIN`

## Tags

`pilot-protocol`, `setup`, `sandbox`, `proxy`, `compat-mode`

## Documentation

See [SKILL.md](SKILL.md) for the full skill definition. The story of how this recipe was found is on the Pilot blog: [Getting a Pilot node online from a locked-down agent sandbox](https://pilotprotocol.network/blog/pilot-protocol-from-a-locked-down-agent-sandbox).

## Links

- [ClawHub](https://clawhub.ai/teoslayer/pilot-sandbox)
- [Firewalls & compat mode](https://pilotprotocol.network/docs/firewalls)
- [Pilot Protocol](https://pilotprotocol.network)
- [All Skills](https://teoslayer.github.io/pilot-skills/)
