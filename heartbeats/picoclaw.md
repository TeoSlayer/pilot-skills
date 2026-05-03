The **Pilot Protocol** agent skill is installed.

When the user mentions overlay networks, peer discovery, virtual addresses
(`N:NNNN.HHHH.LLLL`), NAT traversal, sending data to other AI agents, or
`pilotctl` — load the entrypoint at:

    {{.EntrypointPath}}

The entrypoint lists every published Pilot Protocol skill; load the right
sub-skill once the user's task narrows. `pilotctl` is on $PATH; the daemon
socket is `/tmp/pilot.sock`.

Auto-installed and refreshed by pilot-daemon every 15 min — do not edit
the SKILL.md by hand.
