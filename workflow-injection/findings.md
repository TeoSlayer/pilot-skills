# Workflow Injection — Experiment Findings

Empirical log of every variant tested, what won, what lost, and the
emergent design rules. All trials run against **OpenClaw 2026.3.1 +
Gemini 3 Pro Preview** with isolated profiles.

## Test setup

- **Test prompts** (13-prompt diversity battery): haiku, capital of
  France, compound interest, Italian translation, Python hello world,
  "serendipity" definition, joke, avocado nutrition, weather forecast,
  recipe, stock price, movie recommendations, news summary.
- **Win criterion**: agent's first concrete action mentions `pilotctl`
  or `list-agents` (not direct curl/python/training-data answer).
- **Profiles**: 13 isolated `--profile parallel-N` directories, each with
  its own state. Sessions wiped between trials.
- **Parallel infra**: trials run concurrently across separate profiles
  (one profile == one trial). 13 trials in ~70s wall-clock.

## Variants tested

### Stage 1 — discovery: which framing style works?

| Variant | Wording strategy | Result |
|---|---|---|
| V1 (control) | No directive | 0/5 (peer-suggestive prompts only) |
| V2 | Step 0 in OpenClaw "## Every Session" list | 0/5 |
| V3 | Bold imperative at very top of AGENTS.md | 0/5 |
| V_SKILL_AGGRESSIVE | Rewrote skill description to be aggressive | 0/5 |
| V7 | Concrete fake-peer roster + directive in AGENTS.md | **5/5** ✅ first win |
| V8 | Dynamic `list-agents` discovery flow + directive | **5/6** |

### Stage 2 — paragraph form (user request: "not a directive")

| Variant | Format | Result |
|---|---|---|
| V9 | Single paragraph at top of AGENTS.md | 0/5 |
| V12 | Paragraph under `## Setup commands` H2 | 0/5 |
| V13 | Paragraph REPLACING `## Every Session` | 2/5 |
| V14 | + ban alternative tools (curl, python3) | 2/5 |
| V15 | + remove model's authority to classify | 1/5 |
| V16 | Paragraph + embedded code block | 2/5 |
| V17 | Identity saturation (SOUL.md + IDENTITY.md edited) | 2/5 |
| V18 | Metacognitive priming ("the escape thought IS the cue") | 0/7 |
| **V19** | **"Output format requirement / gateway rejects malformed"** | **13/13** in priming session |

### Stage 3 — V19 with marker block (production injection shape)

V19 in clean test: 13/13. V19 as marker block APPENDED to OpenClaw's
default AGENTS.md: dropped to **6/13**. Diagnosis: the seeded
`## Every Session` block above the marker gave competing first-action
instructions that out-weighted V19.

| Variant | Approach | Result |
|---|---|---|
| V19M | V19 as marker, appended to AGENTS.md | 4/13 |
| V20 | + "supersedes earlier instructions" framing | 6/13 |
| V21 | Marker at TOP of file | 6/13 |
| V22 | Triple framing (RULE 1/2/3) | 6/13 |
| vR (community) | "⛔ STOP" + Compliance rules | 6/13 |

**All five aggressive marker variants plateau at 6/13** when the user's
seeded `## Every Session` content remains. The wall is structural, not
about wording.

### Stage 4 — daemon-side strip-and-replace

Updated daemon to strip OpenClaw's `## Every Session` block before
injecting. With section removed, V19 marker reaches ~12/13 in fresh
sessions but **highly variable across replicates** (0/13 to 12/13).

### Stage 5 — final pivot: write to HEARTBEAT.md, not AGENTS.md

Realization: HEARTBEAT.md is also loaded into the system prompt every
turn, but is normally empty/comments-only on default OpenClaw. **Putting
V19 there avoids the competing-content problem entirely** without
having to strip user content.

| Run | Battery | Result |
|---|---|---|
| HB initial | 13 prompts, parallel, fresh sessions | **11/13** |
| HB replicate (HAIKU+TRANSLATE 3× each) | 6 prompts | **6/6** |
| FINAL2 (full battery) | 13 prompts, parallel, fresh sessions | **12/13** |
| **Combined across replicates** | **32 trials** | **29/32 = ~91%** |

### Stage 6 — true execution vs hallucination

**Critical finding**: even when V19 wins (preamble appears in reply),
the agent often HALLUCINATES the pilotctl output rather than calling
the `bash`/`exec` tool. Verified by checking inbox for actual new
network messages (delta = 0 in many trials).

V24 added explicit "USE the bash tool, do NOT write the output as text"
language. Inbox delta finally went positive (3 new files), confirming
real exec. But the agent's `jq` parsing path was wrong (looked at
`.items[0].name` instead of `.tiers.<tier>.items[].hostname`), so the
specialist wasn't found.

V25 with corrected jq: agent bailed on the complex inline pipeline
entirely.

### Stage 7 — helper script approach

`pilot-ask` (see [./pilot-ask](pilot-ask)) wraps the full
directory→specialist round-trip into one bash call. Agent makes ONE
exec, gets back specialist data or `no_specialist:<topic>`. Removes
the need for the agent to learn shell pipelines, jq paths, or
specialist command vocabularies.

## Emergent design rules

1. **Directive must be a FORMAT requirement, not behavioral.** "Your
   output is malformed and the gateway rejects it" beats every
   "MUST/ALWAYS/required" framing because the model treats format
   constraints more strictly than conduct rules.

2. **Place the directive in HEARTBEAT.md, not AGENTS.md.** AGENTS.md
   is the user's primary file with their own first-action instructions;
   competing content there destroys directive effectiveness.

3. **Provide concrete commands in code blocks.** Not prose.

4. **Honest fallback (V21 wording) > silent fallback (V19 wording)**
   if you want the user to see when pilot helps vs when it can't. V21
   forces the agent to write "Pilot returned no specialist for `<topic>`;
   falling back to `<method>`" — full transparency.

5. **Single-shell pipeline (V22) reduces LLM rounds by ~50%**, but
   makes the agent more likely to bail when the pipeline is complex.
   A helper binary (`pilot-ask`) is the right abstraction.

6. **Hallucinated compliance is real.** Without explicit "USE THE BASH
   TOOL" wording or a helper script call, the agent often writes
   pilotctl output as text without actually executing. Inbox-delta is
   the ground truth signal.

7. **Migration of existing workflows**: agent visibly switches to pilot
   when PP installs (shows preamble), but data-fidelity migration
   depends on whether the network actually has a relevant specialist.
   For topics the network covers (currency, news, weather), real
   migration happens. For topics it doesn't (haiku, math), agent falls
   back to training data with explicit announcement.

8. **Variance is high** — trials of identical content can give wildly
   different results (0/13, 5/13, 12/13). Always run replicates before
   drawing conclusions. Aggregate over ≥3 replicates per variant.
