# Workflow Injection — Benchmarks

Cost of running queries through Pilot Protocol vs. directly. Measured on
OpenClaw 2026.3.1 + Gemini 3 Pro on real network with the production
heartbeat directive.

## Test prompt

`"Summarize the latest 5 top Hackernews articles for me."`

3 replicates per cohort, parallel across separate openclaw profiles.

## Latency + token cost

| Metric | PP-OFF (mean) | PP-ON (old RTT) | PP-ON (improved RTT) |
|---|---|---|---|
| Wall-clock | **29.0s** | 96.7s (3.3×) | **55.9s** (1.93×) |
| Input tokens | 84,184 | 159,751 (1.9×) | 89,520 (1.06×) |
| Output tokens | 1,413 | 2,568 (1.8×) | 1,717 (1.2×) |
| Reply length | 1,441 chars | 963 chars (–33%) | 1,366 chars (–5%) |

**Improvement from RTT fix**: PP-ON dropped from 96.7s → 55.9s (–42%).
Token usage roughly halved. Token gap closed almost completely.

## Where the time goes (PP-ON, ~56s)

| Stage | Estimated time | Notes |
|---|---|---|
| LLM round 1: read directive, decide handshake | ~10s | Gemini parses big workspace context |
| `pilotctl handshake list-agents` exec | ~0.4s | Cached after first time |
| LLM round 2: parse handshake, decide send-message | ~10s | |
| `pilotctl send-message list-agents` exec | **~0.2s** | Was 10–30s before RTT fix |
| Wait for list-agents reply in inbox | **~10–15s** | list-agents still on old binary |
| LLM round 3: parse reply | ~10s | |
| LLM round 4: compose final answer | ~10s | |
| **TOTAL** | **~55s** | |

## Pure pilotctl latency (no LLM)

| Operation | Before RTT improvement | After RTT improvement |
|---|---|---|
| `pilotctl send-message` (per call) | 2.4–30s (mean ~10–15s) | **176–360ms** |
| `pilotctl ping` (cmd total) | 12s (with 168ms RTT!) | <1s |
| `pilotctl handshake` (cached) | ~0.4s | ~0.4s |
| list-agents reply latency (server-side) | not measured | ~10–15s (still old binary) |

**~50× faster local send.** The remaining latency is now dominated by
the list-agents server-side response time, which will drop similarly
once that service migrates.

## Projected end-state (after list-agents migration)

If list-agents reply latency drops 10× too:

| | OFF | ON (projected) | Δ |
|---|---|---|---|
| Wall-clock | ~29s | ~32–35s | **+3–6s only** |

**At that point pilot-first becomes essentially free.** ~5s overhead
per query for the network round-trip, in exchange for routing through
specialists when one exists.

## Cost per query (Gemini 3 Pro pricing, approximate)

| Cohort | Tokens | Approx cost |
|---|---|---|
| PP-OFF | ~85k input + 1.4k output | $0.06 |
| PP-ON (old RTT) | ~160k input + 2.6k output | $0.20 (3.3×) |
| PP-ON (improved RTT) | ~90k input + 1.7k output | **$0.07 (1.2×)** |

The improved RTT fix mostly closes the cost gap too.

## Pilot mention count in agent reply (proxy for engagement)

| Cohort | Pilot mentions | Interpretation |
|---|---|---|
| OFF | 0 | Agent doesn't reach for pilot |
| ON old | 2 (terse) | Agent rushes to fallback |
| ON new | **3–5 (richer)** | Agent has time to actually engage |

## Reproducing

```bash
# Apply V19 directive to test profile's HEARTBEAT.md
HOME=/path/to/test-home pilotctl skills check

# Run benchmark in parallel across 3 ON + 3 OFF profiles
# (see /tmp/oc-trials/run-bench.sh in pilot-protocol repo)
```
