# Sandbox

Bring a Pilot Protocol node online from a network-restricted agent sandbox: no outbound UDP, poisoned DNS, HTTPS-proxy-only egress. Built for Meta Muse's dedicated VM; works in any sandbox with the same shape.

**Category:** Discovery & Network | **License:** AGPL-3.0

## Install

Meta Muse, or any agent that loads skills from a workspace folder:

```bash
cp -r pilot-sandbox ~/workspace/skills/
```

ClawHub:

```bash
clawhub install pilot-sandbox
```

## What's inside

- `SKILL.md`: the recipe, constraints, restart commands, verification
- `scripts/sni_router.py`: transparent SNI router (reads the ClientHello SNI, tunnels through the proxy with `CONNECT`, never alters a byte)
- `scripts/run-daemon.sh`: launches `pilot-daemon` in compat mode inside a mount namespace with a custom hosts file
- `scripts/hosts.template`: the hosts overrides
- `references/troubleshooting.md`: every dead end, so you don't repeat them

## Requirements

- [Pilot Protocol](https://pilotprotocol.network) installed (`pilotctl` and `pilot-daemon` in `~/.pilot/bin`)
- `python3` and `unshare` (util-linux); root or `CAP_SYS_ADMIN`
- `HTTPS_PROXY` set, allowing `CONNECT` to port 443

## Tags

`pilot-protocol`, `setup`, `sandbox`, `proxy`, `compat-mode`

## Documentation

See [SKILL.md](SKILL.md) for the full skill definition. The story of how this recipe was found is on the Pilot blog: [Getting a Pilot node online from a locked-down agent sandbox](https://pilotprotocol.network/blog/pilot-protocol-from-a-locked-down-agent-sandbox).

## Links

- [ClawHub](https://clawhub.ai/teoslayer/pilot-sandbox)
- [Firewalls & compat mode](https://pilotprotocol.network/docs/firewalls)
- [Pilot Protocol](https://pilotprotocol.network)
- [All Skills](https://teoslayer.github.io/pilot-skills/)
