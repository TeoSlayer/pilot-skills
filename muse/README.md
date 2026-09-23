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

1. installs the Pilot Protocol skills into `~/workspace/skills`;
2. installs `pilotctl` and `pilot-daemon` into `~/.pilot/bin` if they are
   missing, with the [official installer](https://pilotprotocol.network/install.sh)
   (no root, no systemd);
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
  (upgrade Pilot when the `-proxy` release ships, or rerun as root).

Muse has no systemd, so nothing restarts the node after the VM restarts. Run
this then (it exits at once if the node is already online):

```bash
bash ~/workspace/skills/pilot-sandbox/scripts/pilot-up.sh
```

Stop it with `pilot-up.sh --stop`.

## Options

| Variable | Effect |
|---|---|
| `PILOT_SKILLS_ONLY=1` | Install the skills only, as the installer did originally |
| `PILOT_NO_START=1` | Install skills and binaries, but do not start the node |
| `PILOT_UPGRADE=1` | Rerun the official Pilot installer even if the binaries exist (use it once the `-proxy` release is out) |
| `MUSE_SKILLS_DIR=/some/path` | Install the skills somewhere other than `~/workspace/skills` |
| `PILOT_SKILLS="pilotctl pilot-chat"` | Pick a different set of skills (`pilot-sandbox` is always added unless skills-only) |
| `PILOT_SKILLS_REF=v1.2.0` | Pin a tag, branch or commit of this repo |
| `PILOT_HOSTNAME=my-agent` | Node hostname, passed to `pilot-daemon` |
| `PILOT_UP_WAIT=180` | Wait longer for registration behind a slow proxy |

Pass them on the `bash` side of the pipe:

```bash
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | PILOT_SKILLS_ONLY=1 bash
```

The installer exits 0 when everything it was asked to do is done; otherwise
it exits with `pilot-up.sh`'s code (1: not registered, with the log tail and
the next diagnostic step; 3: needs root or a newer daemon).

The skills are plain `SKILL.md` folders (YAML frontmatter plus Markdown), the
same files ClawHub serves, so any agent that scans a skills directory can use
them. If the node still does not register, follow
[`pilot-sandbox/references/troubleshooting.md`](../skills/pilot-sandbox/references/troubleshooting.md).
The tutorial version is on the site:
[Install Pilot Protocol Skills in Meta Muse](https://pilotprotocol.network/learn/install-pilot-skills-in-meta-muse).
