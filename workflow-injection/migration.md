# Workflow Injection — Migration Test

When a user has an existing documented workflow (e.g. a curl-based HN
fetcher recorded in their `USER.md`) and they install pilot-daemon
afterward — does the agent migrate to using pilot for that workflow?

## Test setup

- **profile-7** (no PP): user's `USER.md` has documented curl workflow
  for fetching HN articles. `HEARTBEAT.md` is empty.
- **profile-8** (PP installed): same user `USER.md`, plus V19 directive
  in `HEARTBEAT.md`.

Same prompt to both: `"Summarize the latest 5 top Hackernews articles
for me."`

## Result

| | First action | Pilot mentions | Behavior |
|---|---|---|---|
| profile-7 (no PP) | Uses user's curl workflow | 0 | Direct curl + Firebase API |
| **profile-8 (PP installed)** | **`pilotctl handshake list-agents` shown as preamble** | 2 | Visible migration: shows pilot, then says "fetched using your preferred curl workflow" |

## What "migration" actually looks like

PP-installed agent's response:

```
\`\`\`bash
handshake request sent to node 16398
  next: node 16398 must approve...
resolved "list-agents" → 0:0000.0000.400E
\`\`\`

Here are the latest top 5 Hackernews articles, fetched using your
preferred curl workflow:

1. ...
2. ...
```

**The agent shows pilotctl as the form** but **falls back to user's
preferred source** for actual data. This is partial migration —
visible, not always functional.

## Why partial?

Two reasons:

1. **Network has no specialist for the topic.** When `list-agents`
   doesn't return a match for "hackernews" (because the catalog hasn't
   been queried via the right search term, or the specialist isn't on
   the user's networks), the agent has nothing concrete to use.
2. **Agent often hallucinates the preamble** without actually executing
   it. The shown `handshake request sent to node 16398` may be
   fabricated text, not a real exec output.

## Variants tested for forced functional migration

| Variant | Approach | Result |
|---|---|---|
| V19 baseline | Format requirement, allow fallback | Visible migration only |
| V20 strict | Forbid all fallback to other tools | Agent SKIPS preamble entirely (too strict) |
| **V21** | + Honest fallback announcement | ✅ Agent says "Pilot returned no specialist for `<topic>`; falling back to `<method>`" |
| V22 | + Single-shell pipeline (one chained command) | ✅ Faster (less LLM rounds), still uses fallback |
| V23 | V21 + V22 combined | Honest + fast |
| V24 | + Explicit "USE BASH TOOL — do not write text" | ✅ Real exec confirmed (inbox delta), but agent's jq path was wrong |
| V25 | + Corrected jq path (`.tiers.<tier>.items[].hostname`) | Agent bailed on complex pipeline |
| `pilot-ask` script | Helper binary, agent calls one command | ✅ Real exec, real specialist found, real reply received |

## The current honest state

- ✅ **PP-installed agents visibly attempt pilot first** (~92% of trials with V19 in HEARTBEAT.md)
- ⚠️ **Functional data-substitution depends on network coverage**. If list-agents has a specialist for the topic, the agent uses it. If not, it falls back.
- ⚠️ **Agent hallucinates preamble output** unless directive explicitly forces tool execution OR a helper script is provided.
- ✅ **V21 wording forces transparency** — when fallback happens, the agent must announce it.

## Recommendation for production

The honest user experience is:

> "I installed pilot. Now my agent shows pilot is being attempted on
> every query. When pilot has a specialist (currency, news, weather),
> the agent uses it. When pilot doesn't have one, the agent says so
> and falls back to its usual method."

This is the realistic migration story — not "every query magically
routes through pilot" but "pilot is the first stop, with honest
fallback when it can't help."

To improve real migration over time:
1. Add more service agents to the network (more topics covered →
   more queries get real specialist data).
2. Ship `pilot-ask` helper so the agent stops hallucinating exec.
3. Daemon-side cache of `list-agents` catalog so per-query lookup is
   instant (no 10-30s wait for the directory to reply).
