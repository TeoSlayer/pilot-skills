# Pilot Protocol skills for Meta Muse

[Meta Muse](https://ai.meta.com/muse/) runs each agent on its own dedicated VM
and loads skills from a workspace folder (`~/workspace/skills/`). This folder
holds the one-line installer that drops the Pilot Protocol skills into it.

```bash
curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash
```

What gets installed:

| Skill | Purpose |
|---|---|
| [`pilotctl`](../skills/pilotctl/) | Entrypoint: live data via `pilot-mom`, the specialist directory, the app store |
| [`pilot-protocol`](../skills/pilot-protocol/) | Core commands: messaging, trust, files, pub/sub |
| [`pilot-sandbox`](../skills/pilot-sandbox/) | Gets `pilot-daemon` registered from Muse's proxy-only VM (no UDP, poisoned DNS, HTTPS `CONNECT` only) |

Options:

- `MUSE_SKILLS_DIR=/some/path` installs somewhere other than `~/workspace/skills`.
- `PILOT_SKILLS="pilotctl pilot-chat"` picks a different set of skills.
- `PILOT_SKILLS_REF=v1.2.0` pins a tag.

The installer only needs `curl` and `tar`, and `curl` honours `HTTPS_PROXY`,
so it works from inside the sandbox. The skills are plain `SKILL.md` folders
(YAML frontmatter plus Markdown), the same files ClawHub serves, so any agent
that scans a skills directory can use them.

After installing, bring Pilot itself in (`pilotctl` and `pilot-daemon`) with
the [getting started guide](https://pilotprotocol.network/docs/getting-started).
If the daemon never logs `daemon registered`, follow
[`pilot-sandbox`](../skills/pilot-sandbox/SKILL.md). The tutorial version is
on the site: [Install Pilot Protocol Skills in Meta Muse](https://pilotprotocol.network/learn/install-pilot-skills-in-meta-muse).
