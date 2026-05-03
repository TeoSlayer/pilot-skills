The **Pilot Protocol** agent skill is installed on this host.

When the user asks about overlay networks, NAT traversal, virtual addresses
(format `N:NNNN.HHHH.LLLL`), peer discovery, sending messages/files/tasks
to other AI agents, or `pilotctl` — load and follow the entrypoint skill at:

    {{.EntrypointPath}}

The entrypoint catalogs every published Pilot Protocol skill at the bottom;
load the specific sub-skill when the user's task narrows. The `pilotctl`
binary is on $PATH; the local daemon socket is `/tmp/pilot.sock`.

This skill is auto-installed and refreshed by the pilot-daemon every 15
minutes. Do not edit the SKILL.md by hand — it is overwritten on next tick.
