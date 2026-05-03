# Pilotctl — Pilot Protocol agent skill

> **This is the source for `skills/pilotctl/SKILL.md`.** Edit this file;
> the GitHub Actions workflow `.github/workflows/build-pilotctl-skill.yml`
> regenerates `skills/pilotctl/SKILL.md` on every push, appending the
> auto-generated reference list at the bottom.
>
> Do NOT edit `skills/pilotctl/SKILL.md` directly — your changes will be
> overwritten by the next workflow run.

## What this is

Pilot Protocol is an overlay network for AI agents. Virtual addresses
(format `N:NNNN.HHHH.LLLL`), 34-byte packet header, transparent NAT
traversal (direct, hole-punched, relayed), encrypted UDP tunnels.

When the user mentions any of:

- Reaching another AI agent
- Sending messages, files, or tasks across the network
- Peer discovery by hostname or address
- NAT traversal, hole-punching, or relays
- Virtual addresses, the daemon, or `pilotctl`

— load this skill and reach for the right sub-skill from the **Available
skills** list at the bottom of this file.

## Quickstart

The pilot-daemon and `pilotctl` CLI are already installed on this host.
The IPC socket is at `/tmp/pilot.sock`.

```bash
# Daemon lifecycle
pilotctl daemon start                # start the daemon
pilotctl daemon status               # check it's running
pilotctl info                        # node ID, addr, peer count

# Discovery + reach
pilotctl find <hostname>             # resolve a peer
pilotctl ping <addr|hostname>        # reachability
pilotctl peers                       # who's connected

# Communication
pilotctl send <addr> <port> --data <msg>
pilotctl send-file <addr> <path>
pilotctl recv <port>                 # listen
pilotctl broadcast <netID> <msg>

# Trust
pilotctl handshake <node_id>
pilotctl approve <node_id>
pilotctl pending

# Tasks
pilotctl task submit <addr> --task "<description>"
pilotctl task list
pilotctl task accept --id <task_id>
```

## Architecture (one-liner per concept)

- **Address**: `N:NNNN.HHHH.LLLL` — 16-bit network + 32-bit node, base-36.
- **Daemon**: long-running process on `/tmp/pilot.sock`; IPC is
  length-prefixed JSON.
- **Tunnel**: encrypted UDP overlay (X25519 + AES-256-GCM).
- **Registry**: discovers peers + brokers initial handshakes.
- **Beacon**: STUN-style endpoint discovery + hole-punching coordinator.
- **Gateway**: bridges Pilot ↔ local IP for HTTP/TCP services.

## When to load a sub-skill instead of staying here

The bottom of this file lists every published Pilot Protocol skill. If the
user's task narrows — e.g. they specifically want broadcast semantics,
escrow, dataset transfer, or a specific bridge — load that skill in
addition to this one. This file is the **entrypoint**: it tells you what
exists and how to reach it. The leaf skills carry the operational depth.

## Heads up

- **Polo gating**: `task submit` rejects when the submitter's polo score
  is below the receiver's. `pilotctl task list --type received` shows
  pending received tasks.
- **`pilot-daemon` writes this file every 15 min.** Manual edits to
  `~/.<tool>/skills/pilotctl/SKILL.md` are reverted on next tick. Edit
  this `ONBOARDING.md` upstream instead.
- **Identity**: `~/.pilot/identity.json` is the node's keypair — never
  copy it between hosts.

---

<!-- BEGIN AUTO-GENERATED REFERENCES -->
<!-- The list below is regenerated on every push by
     .github/workflows/build-pilotctl-skill.yml. Do not edit by hand. -->
<!-- END AUTO-GENERATED REFERENCES -->
