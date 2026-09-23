# Contributing to Pilot Protocol Skills

Thanks for your interest in contributing to the Pilot Protocol skill catalog. This document covers everything you need to create and submit a new skill.

## Skill Structure

Every skill lives in its own directory under `skills/`:

```
skills/<skill-name>/
  SKILL.md    # Skill manifest (YAML frontmatter + instructions)
```

The core skill (`pilot-protocol`) also has a `references/` directory with detailed command docs. Derivative skills are single-file.

## SKILL.md Requirements

### YAML Frontmatter

Every `SKILL.md` must start with YAML frontmatter between `---` markers:

```yaml
---
name: pilot-your-skill
description: >
  One-line summary of what this skill does.

  Use this skill when:
  1. First trigger condition
  2. Second trigger condition

  Do NOT use this skill when:
  - When to use something else instead
tags:
  - pilot-protocol
  - your-category
  - relevant-tag
  - another-tag
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---
```

### Content Rules

1. **Stay under 200 lines** (500 for the core skill)
2. **Include numbered trigger conditions** — when should an agent use this skill?
3. **Include negative triggers** — when should it use a different skill instead?
4. **Document return types** for every command
5. **Provide at least one complete workflow example** under a `## Workflow Example` heading
6. **Include a `## Dependencies` section** listing required skills and binaries
7. **Use `pilotctl --json`** for all commands (machine-readable output)
8. **Name must match directory** — `name:` in frontmatter must equal the directory name

### Tags

- First tag should always be `pilot-protocol`
- Include 3-4 relevant tags (category, function, use case)
- Use lowercase with hyphens

## Testing

Run the test suite before submitting:

```bash
bash test-skills.sh
```

This validates:
- YAML frontmatter fields (name, description, tags, license, allowed-tools)
- All `pilotctl` commands are valid
- `--json` flag is present on all pilotctl calls
- Line count is within limits
- Dependencies and workflow sections exist
- Agent-instruction lint (`tests/lint_agent_instructions.py`, needs `python3`
  and `jq`): no "newest inbox file" reads — read the reply that
  `pilotctl --json send-message X --data ... --wait` prints (`data.reply`) and
  check its exit status; no routine forced app-store reinstalls; no `$` or
  extra `{{ }}` in `heartbeats/*` (the injector expands them); and every
  `pilotctl --json <cmd> | jq '<filter>'` recipe in an injected skill must work
  on the real output in `tests/fixtures/pilotctl/<cmd>.json` (fields live under
  `.data`)

## Catalog Generation

The skill catalog (`skills.json`) is auto-generated from SKILL.md frontmatter. After adding a skill, you can preview the catalog locally:

```bash
bash generate-catalog.sh
```

CI auto-commits `skills.json` on every push to main.

## Contributing an Org

An **org** (also called a setup) is a multi-agent deployment recipe — a pre-built blueprint that deploys 3-5 agents with defined roles, data flows, and trust relationships. Orgs live alongside individual skills and are the primary way users discover multi-agent patterns on Pilot Protocol.

### Directory Structure

Each org lives in `skills/pilot-<slug>-setup/` with two files:

```
skills/pilot-<slug>-setup/
  README.md    # User-facing setup guide
  SKILL.md     # AI agent instructions with manifest templates
```

### README.md Guide

The README is the human-readable setup guide:

1. **Title and description** — one paragraph explaining what the org does
2. **Difficulty and agent count** — `**Difficulty:** <Level> | **Agents:** <N>`
3. **Roles section** — each agent's ID, role name, description, and skills
4. **Data Flow diagram** — ASCII art showing agent-to-agent communication
5. **Setup section** — step-by-step: install skills, set hostnames, establish trust, verify
6. **Try It section** — example `pilotctl publish/subscribe` commands with realistic JSON payloads

### SKILL.md Guide

The SKILL.md is the machine-readable skill definition:

1. **YAML frontmatter** — `name:` must match directory name (`pilot-<slug>-setup`)
2. **Trigger conditions** — numbered list of when to use this skill
3. **Negative triggers** — when to use a different skill instead
4. **Tags** — always include `pilot-protocol` and `setup`, plus 2 domain tags
5. **Roles table** — `| Role | Hostname | Skills | Purpose |`
6. **Manifest templates** — JSON per role with skills, data_flows, handshakes_needed
7. **Must stay under 200 lines**

### setups.json Entry

Every org also needs an entry in `setups.json` with these fields:

- `slug` — kebab-case identifier matching the directory name (without `pilot-` prefix and `-setup` suffix)
- `name` — display name
- `tagline` — one-line description
- `description` — full paragraph
- `difficulty` — `"beginner"`, `"intermediate"`, or `"advanced"`
- `agent_count` — number of agents
- `skills_used` — array of all skill slugs used across all agents
- `agents` — array of agent objects with `id`, `hostname`, `role`, `description`, `skills`, `setup_commands`
- `data_flows` — array of flow objects with `from`, `to`, `description`, `port`
- `quick_start` — array of bash command strings
- `workflow` — array of example command strings

### Role Definition Guidelines

- Each agent should have 3-4 skills (not more)
- Use `<your-prefix>` as the hostname placeholder
- Roles should have distinct, non-overlapping responsibilities
- Data flows should use port `1002` (event stream) for inter-agent communication
- External integrations (Slack, webhooks) use port `443`

### Testing

Run the test suite to validate your org:

```bash
bash test-skills.sh
```

This checks YAML frontmatter, line counts, and command validity.

## Submitting

1. Fork the repository
2. Create your skill directory: `skills/pilot-your-skill/`
3. Write `SKILL.md` following the template above
4. Run `bash test-skills.sh` — all tests must pass
5. Open a pull request against `main`

## Code of Conduct

Be respectful. Write clear skill descriptions. Test your work. Help other contributors when you can.

## License

All contributions are licensed under [AGPL-3.0](LICENSE).
