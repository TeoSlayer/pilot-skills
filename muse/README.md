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

- **Fast path:** a `pilot-daemon` with the `-proxy` flag (the release after
  v1.13.9; version TBD) sends every connection through `HTTPS_PROXY` itself,
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
- It uses the daemon's `-transport=auto` when `pilot-daemon -h` offers it,
  `-transport=compat` otherwise.

Muse has no systemd, so nothing restarts the node after the VM restarts. Run
this then (it exits at once if the node is already online):

```bash
bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh
```

Stop it with `pilot-up.sh --stop`. Pid files that a VM restart leaves behind
are checked against the process command line and removed, never signalled.

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

The installer creates the empty file `~/.pilot/targets/muse` (in every mode,
including `PILOT_SKILLS_ONLY=1`). It records that this host is a Muse target:
Pilot's skill injection will key off it to find `~/workspace/skills` and keep
the skills there current.

## Options

| Variable | Effect |
|---|---|
| `PILOT_SKILLS_ONLY=1` | Install the skills only, as the installer did originally |
| `PILOT_NO_START=1` | Install skills and binaries, but do not start the node |
| `PILOT_UPGRADE=1` | Rerun the official Pilot installer even if the binaries exist, and restart the node when they changed (use it once the `-proxy` release is out) |
| `PILOT_MUSE_FRONTMATTER=0` | Keep each skill's original frontmatter instead of the Muse shape |
| `MUSE_SKILLS_DIR=/some/path` | Install the skills somewhere other than `~/workspace/skills` |
| `PILOT_SKILLS="pilotctl pilot-chat"` | Pick a different set of skills (`pilot-sandbox` is always added unless skills-only) |
| `PILOT_SKILLS_REF=v1.2.0` | Pin a tag, branch or commit of this repo |
| `PILOT_HOSTNAME=my-agent` | Node hostname, passed to `pilot-daemon` |
| `PILOT_UP_WAIT=180` | Wait longer for registration behind a slow proxy |
| `PILOT_REGISTRY_TRUST=pinned` | Skip the system-trust attempt (`system` disables the automatic pinned retry) |
| `PILOT_REGISTRY_FINGERPRINT=<hex>` | Registry certificate pin to use instead of the bundled one |

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
