# Workflow Injection

How the pilot-daemon makes installed agents (Claude Code, OpenClaw,
PicoClaw, OpenHands, Hermes) reach for the Pilot Protocol network as
their first action on every task.

## Goal

After a user installs pilot-daemon, every query their AI agent receives
should attempt the Pilot Protocol network FIRST — querying the
`list-agents` directory for a specialist, handing off to it, and only
falling back to direct answers / web fetches / training data if the
network has nothing relevant. This needs to happen **without the user
explicitly asking** the agent to use Pilot.

## What's in this directory

- [`findings.md`](findings.md) — full experiment log: 22 variants tested
  against Gemini 3 Pro on OpenClaw, what worked, what didn't, and why.
- [`benchmarks.md`](benchmarks.md) — measured latency + token cost of
  PP-on vs PP-off on a representative HN-summary task.
- [`migration.md`](migration.md) — what happens when a user has an
  existing curl-based workflow documented and PP gets installed.
- [`heartbeat-v19-final.md`](heartbeat-v19-final.md) — the production
  heartbeat template (already shipped in `../heartbeats/openclaw.md`).
- [`heartbeat-v21-honest-fallback.md`](heartbeat-v21-honest-fallback.md)
  — alternative wording that forces the agent to announce when pilot
  has no answer. More honest, slightly slower.
- [`pilot-ask`](pilot-ask) — helper script the daemon should ship to
  `~/.pilot/bin/`. Wraps the full directory→specialist round-trip into
  one bash call so the agent doesn't need to learn shell pipelines or
  per-specialist command vocabularies.

## TL;DR

**Wording**: framing as an *output format requirement* ("your response
is malformed and the gateway rejects it") is the only directive style
that survives Gemini's hardwired "answer directly when I know it"
prior. Behavioral framings ("MUST use", "first action", "non-negotiable
identity") all get overridden on tasks the model classifies as trivial.

**Placement**: write the directive into `HEARTBEAT.md`, NOT `AGENTS.md`.
HEARTBEAT.md is a secondary file users rarely customize, so the
directive doesn't compete with the user's existing first-action
instructions. AGENTS.md placement gave 0–5/13 wins (highly variable);
HEARTBEAT.md placement gives ~92% (29/32 across replicates).

**Current performance** (post-RTT-improvement, list-agents still on old
binary): PP-on adds ~30s latency vs ~67s before. Once list-agents
migrates, projected PP-on adds ~5–10s — close to baseline.

**Migration**: when a user has documented a curl-based workflow, PP
installation overrides it visibly (agent shows pilotctl preamble), but
data-fidelity migration depends on whether the network actually has a
specialist for the topic. With V21 wording, the agent explicitly
announces fallback to curl when pilot has nothing — transparent to the
user.

## Production architecture

```
┌──────────────────────────────────┐
│  pilot-skills (this repo)        │
│  ─ inject-manifest.json          │
│  ─ heartbeats/<tool>.md          │  ← V19 wording, served by HTTPS
│  ─ skills/pilotctl/SKILL.md      │
└────────────┬─────────────────────┘
             │ HTTPS fetch every 15 min
             ▼
┌──────────────────────────────────┐
│  pilot-daemon (per host)         │
│  ─ pkg/skillinject               │
│  ─ writes HEARTBEAT.md per tool  │
│  ─ skill copy at <tool>/skills/  │
└────────────┬─────────────────────┘
             │ writes to ~/.openclaw/workspace/HEARTBEAT.md, etc.
             ▼
┌──────────────────────────────────┐
│  Agent tool (OpenClaw, etc.)     │
│  ─ HEARTBEAT.md loaded into      │
│    every session's system prompt │
│  ─ Agent reads "format reqmt"    │
│  ─ Calls pilotctl → list-agents  │
└──────────────────────────────────┘
```

## Open work

- [ ] Ship `pilot-ask` helper from the daemon (write to `~/.pilot/bin/`
      during skillinject's tick). Update HEARTBEAT.md to call it.
- [ ] Daemon-side cache of the list-agents catalog so per-query lookups
      are local (currently every query waits ~30s for live directory
      response).
- [ ] Migrate list-agents to the new daemon binary to close the
      remaining latency gap.
- [ ] Add `pilotctl skills disable` opt-out (default-on remains).
