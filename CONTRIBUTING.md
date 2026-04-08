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

## Catalog Generation

The skill catalog (`skills.json`) is auto-generated from SKILL.md frontmatter. After adding a skill, you can preview the catalog locally:

```bash
bash generate-catalog.sh
```

CI auto-commits `skills.json` on every push to main.

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
