# Pilot Protocol in Meta Muse

[Meta Muse](https://ai.meta.com/muse/) runs each agent on its own dedicated VM
and loads skills from a workspace folder (`~/workspace/skills/`). The VM has
no outbound UDP, poisons DNS for the Pilot hostnames, and only lets HTTPS out
through an authenticating proxy (`HTTPS_PROXY`). This folder holds the
one-shot installer that gets a Pilot node online from inside it:

```bash
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash
```

In one run it:

1. installs the Pilot Protocol skills into `~/workspace/skills`, with the
   frontmatter Muse is known to load (see below), and marks the host as a
   Muse target by creating the empty file `~/.pilot/targets/muse`;
2. installs `pilotctl` and `pilot-daemon` into `~/.pilot/bin` if they are
   missing, with the [official installer](https://pilotprotocol.network/install.sh)
   (no systemd needed; Muse runs the agent as root, so it passes
   `PILOT_ALLOW_ROOT=1`, and `PILOT_TRANSPORT=compat` when a proxy is set);
3. brings the node online with
   [`pilot-sandbox/scripts/pilot-up.sh`](../skills/pilot-sandbox/scripts/pilot-up.sh)
   and waits for `daemon registered`.

Every download is plain `curl`, which honours `HTTPS_PROXY`. Proxy
credentials are never printed.

What gets installed:

| Skill | Purpose |
|---|---|
| [`pilotctl`](../skills/pilotctl/) | Entrypoint: live data via `pilot-mom`, the specialist directory, the app store |
| [`pilot-protocol`](../skills/pilot-protocol/) | Core commands: messaging, trust, files, pub/sub |
| [`pilot-sandbox`](../skills/pilot-sandbox/) | Gets `pilot-daemon` registered from Muse's proxy-only VM, and back online after a restart |

## How the node comes up

`pilot-up.sh` runs `pilot-daemon` directly in compat mode (registry TLS and
beacon WSS, both on `:443`) under a small respawn loop, logging to
`~/.pilot/daemon.log`:

- **Fast path:** a `pilot-daemon` whose `-h` lists `-proxy`
  (pilotprotocol#470; v1.13.10 and earlier do not have it) sends every
  connection through `HTTPS_PROXY` itself,
  asking the proxy to `CONNECT` by hostname. No root.
- **Fallback:** an older daemon needs the SNI-router recipe from
  [`pilot-sandbox`](../skills/pilot-sandbox/SKILL.md), which needs root with
  `CAP_SYS_ADMIN`. Without it, `pilot-up.sh` exits 3 and prints what to do
  (upgrade Pilot with `PILOT_UPGRADE=1` when the `-proxy` release ships, or
  rerun as root).
- **Registry TLS:** system trust first. If the daemon log shows an x509
  error, `pilot-up.sh` restarts it once with `-registry-trust=pinned` and the
  bundled fingerprint (the settings the first Muse node registered with) and
  says so. `PILOT_REGISTRY_TRUST` and `PILOT_REGISTRY_FINGERPRINT` override it.
- **Transport:** `-transport=compat` whenever a proxy is set or this host is
  marked as Muse. It does not use `-transport=auto` there: auto makes one
  check through the proxy and settles on `udp` when it fails (a 407, a slow
  proxy), and `udp` never uses the proxy. With no proxy, a `"transport"` in
  `config.json` is left to the daemon, else auto when offered.
  `PILOT_UP_TRANSPORT=compat|auto|udp` overrides.
- **Rotating proxy credentials:** Muse rotates them every few minutes and a
  running process keeps the ones it started with, so new connections would
  fail with 407 while `pilotctl --json info` still works ("node online, all
  apps broken"). A fresh shell always has current ones, and the node re-reads
  them there: a `pilot-daemon` with `-proxy-cmd` runs
  a fresh `bash` printing `$https_proxy` (`$HTTPS_PROXY` when only that one
  carries credentials) every 60s and after a 407 (pilot-up hands the daemon
  that command as `PILOT_PROXY_CMD`; the official installer saves the same
  one as `proxy_cmd`); an older daemon
  gets [`egress_relay.py`](../skills/pilot-sandbox/scripts/egress_relay.py) on
  `127.0.0.1:3128` as its proxy, which stamps current credentials on every
  connection, so the daemon and SNI router hold none. That relay serves only
  clients with its token (`~/.pilot/egress_relay.token`, passed to the daemon
  and router through their environment), so other local users cannot borrow
  the proxy credentials. The respawn loop also re-reads them before every
  restart. `pilot-up.sh` prints which mode it uses
  (`PILOT_UP_CREDS=cmd|relay|static` forces one), and so does the installer's
  closing message. If 407s still show up, rerun `pilot-up.sh` from a fresh
  shell: it restarts a relay (on the address the node uses) or router that
  died, and a node started before this handling whose log shows real proxy
  407s (`proxy CONNECT ...: 407`, not any number 407). A node it did not start
  is never stopped for this; it prints a note instead.

Muse has no systemd, so nothing restarts the node after the VM restarts. Run
this then (it exits at once if the node is already online):

```bash
bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh
```

Stop it with `pilot-up.sh --stop`, which also stops a daemon or SNI router
started by hand (found through the socket and the router port) and exits 1
if one survives. Pid files that a VM restart leaves behind are checked
against the process command line and removed, never signalled.

## Skill frontmatter for Muse

The only skill frontmatter proven to load in Muse is a quoted underscore name
and a one-line quoted description:

```yaml
---
name: "pilot_sandbox"
description: "Bring a Pilot Protocol node online from a network-restricted agent sandbox ..."
---
```

So the installer rewrites the frontmatter of each **installed** `SKILL.md`
into that shape: `name` is the folder name with `-` replaced by `_`, the
description is joined onto one line (quotes escaped, capped at 1024 bytes),
and the other keys (`tags`, `license`, `metadata`, ...) are dropped. The body
is untouched, and so are the files in this repo. Set
`PILOT_MUSE_FRONTMATTER=0` to keep the original frontmatter, for agents that
require `name` to match the folder name.

## Muse target marker

The installer writes `~/.pilot/targets/muse` (in every mode, including
`PILOT_SKILLS_ONLY=1`). It records that this host is a Muse target, where the
skills went and in which frontmatter:

```
skills_dir=/root/workspace/skills
skill_format=muse
```

(`skill_format=canonical` with `PILOT_MUSE_FRONTMATTER=0`). Pilot's skill
injection (pilot-daemon's skillinject, the `muse` row under `gatedTools` in
`inject-manifest.json`) keeps the `pilotctl` skill there current only while
the marker names that folder and format; an empty marker attests nothing.

## Options

| Variable | Effect |
|---|---|
| `PILOT_SKILLS_ONLY=1` | Install the skills only, as the installer did originally |
| `PILOT_NO_START=1` | Install skills and binaries, but do not start the node |
| `PILOT_UPGRADE=1` | Rerun the official Pilot installer even if the binaries exist, and restart the node when they changed (use it once a release whose `pilot-daemon -h` lists `-proxy` is out; v1.13.10 does not). The node keeps its egress relay address (`PILOT_RELAY_LISTEN`) across the restart. If the running node cannot be stopped, it says so instead of claiming the new version runs |
| `PILOT_MUSE_FRONTMATTER=0` | Keep each skill's original frontmatter instead of the Muse shape |
| `MUSE_SKILLS_DIR=/some/path` | Install the skills somewhere other than `~/workspace/skills` |
| `PILOT_SKILLS="pilotctl pilot-chat"` | Pick a different set of skills (`pilot-sandbox` is always added unless skills-only) |
| `PILOT_SKILLS_REF=v1.2.0` | Pin a tag, branch or commit of this repo |
| `PILOT_HOSTNAME=my-agent` | Node hostname, passed to `pilot-daemon` |
| `PILOT_UP_WAIT=180` | Wait longer for registration behind a slow proxy |
| `PILOT_REGISTRY_TRUST=pinned` | Skip the system-trust attempt (`system` disables the automatic pinned retry) |
| `PILOT_REGISTRY_FINGERPRINT=<hex>` | Registry certificate pin to use instead of the bundled one |
| `PILOT_PROXY_CMD="<command>"` | Command that prints the current proxy URL (default: a fresh `bash` printing `$https_proxy`), for `-proxy-cmd` and the egress relay |
| `PILOT_RELAY_LISTEN=127.0.0.1:3129` | Where the egress relay listens (default `127.0.0.1:3128`; reruns keep a running node's relay where it is) |

Pass them on the `bash` side of the pipe:

```bash
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | PILOT_SKILLS_ONLY=1 bash
```

`PILOT_HOME` is not supported: everything lives in `$HOME/.pilot`, as it does
for the official installer and `pilot-daemon`.

The installer exits 0 when everything it was asked to do is done; otherwise
it exits with `pilot-up.sh`'s code (1: not registered, with the log tail and
the next diagnostic step; 3: needs root or a newer daemon).

The skills are plain `SKILL.md` folders (YAML frontmatter plus Markdown), the
same files ClawHub serves (with the frontmatter rewrite above unless
`PILOT_MUSE_FRONTMATTER=0`), so any agent that scans a skills directory can
use them. If the node still does not register, follow
[`pilot-sandbox/references/troubleshooting.md`](../skills/pilot-sandbox/references/troubleshooting.md).
The tutorial version is on the site:
[Install Pilot Protocol Skills in Meta Muse](https://pilotprotocol.network/learn/install-pilot-skills-in-meta-muse).
