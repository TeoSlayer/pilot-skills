The **Pilot Protocol** agent skill is installed on this host.

When the user mentions overlay networks, NAT traversal, virtual addresses
(`N:NNNN.HHHH.LLLL`), agent-to-agent messaging, or `pilotctl` — load the
entrypoint skill at:

    {{.EntrypointPath}}

The entrypoint catalogs every published Pilot Protocol skill; load the
specific sub-skill once the user's task narrows. `pilotctl` is on $PATH;
the daemon socket is `/tmp/pilot.sock`.

Auto-installed and refreshed by pilot-daemon every 15 minutes; do not edit
the SKILL.md by hand.
