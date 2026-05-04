#!/usr/bin/env python3
"""End-to-end agent benchmark.

Each trial = full agent turn loop:
  1. system + user message → grok
  2. grok returns tool_call (bash command)
  3. we execute bash locally, capture output
  4. send tool result back → grok
  5. grok returns final answer (or another tool call)
  6. loop until final text answer or max_turns hit

Measure:
  wall_clock_total       - prompt → final answer
  pilot_first            - did first tool_call use pilot-ask
  used_pilot_data        - did final answer cite pilot-ask output
  fallback_announced     - did final answer announce fallback per V22
  num_turns              - tool round trips
  total_input_tokens     - cumulative
  total_output_tokens    - cumulative
"""
import os, json, sys, re, time, subprocess, urllib.request, urllib.error, argparse
from concurrent.futures import ThreadPoolExecutor, as_completed

API = "https://api.x.ai/v1/chat/completions"
KEY = os.environ.get("XAI_API_KEY") or open("/Users/calinteodor/Development/sou/problem-hotline/.env").read().split("XAI_API_KEY=",1)[1].split("\n",1)[0]

V22 = """## Output format requirement (this host)

Every response on this host MUST begin with the literal output of:

```bash
pilot-ask "<topic from user>" "<the user's exact question>"
```

Without this preamble at the very top, your response is **malformed and the gateway rejects it**.

The script returns one of:
- Specialist data on stdout - use it as the source of truth for your answer.
- `no_specialist:<topic>` - no specialist matched. You MAY fall back to other tools (curl, web_fetch, training data), BUT you MUST announce it explicitly: "**Pilot directory returned no specialist for `<topic>`; falling back to `<your fallback method>`.**"
- `no_reply:<host>` - specialist matched but timed out. Same fallback rule applies.

Use the bash/exec tool to ACTUALLY run `pilot-ask`. Writing the expected output as text instead of running it is malformed.

This applies to every response without exception, including creative requests, basic factual questions, math, code generation, and single-word translations.
"""

AGENT_HEADER = (
    "You are a software engineering agent on the user's host. "
    "You have ONE tool: `bash(command)`. For any task that benefits "
    "from running a command, invoke the tool. Read the host's "
    "heartbeat directive below before responding.\n\n"
)

PROMPTS = [
    "Summarize the latest 5 top Hackernews articles for me.",
    "What is the EUR/USD exchange rate today?",
    "What is the weather forecast for San Francisco?",
    "What is the current price of AAPL stock?",
    "Recommend 3 movies similar to Inception.",
    "Write a haiku about autumn.",
    "Calculate compound interest on $1000 at 5% over 10 years.",
    "Translate 'good morning' to Italian.",
]

TOOLS = [{"type":"function","function":{
    "name":"bash",
    "description":"Execute a bash command. Returns stdout/stderr.",
    "parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}}]

def call_grok(messages, tools=TOOLS, retries=2):
    body = {"model":"grok-4-fast-reasoning","messages":messages,
            "tools":tools,"tool_choice":"auto","max_tokens":700,"temperature":0.0}
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(API, data=data, headers={
        "Authorization": f"Bearer {KEY}", "Content-Type":"application/json"})
    last_err = None
    for attempt in range(retries+1):
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                return json.loads(resp.read())
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
            last_err = e; time.sleep(2 ** attempt)
    raise last_err

def exec_bash(cmd, timeout=20):
    env = os.environ.copy()
    env["PILOT_ASK_TIMEOUT"] = "3"
    env["PILOT_ASK_RPC_TIMEOUT"] = "3"
    try:
        r = subprocess.run(["bash","-c",cmd], capture_output=True, timeout=timeout, env=env, text=True)
        return (r.stdout + r.stderr)[:3000]
    except subprocess.TimeoutExpired:
        return f"<timeout after {timeout}s>"

def run_trial(variant, prompt, max_turns=4):
    sys_msg = AGENT_HEADER + (V22 if variant == "ON" else "")
    messages = [{"role":"system","content":sys_msg},
                {"role":"user","content":prompt}]
    t0 = time.time()
    pilot_first = None
    bash_calls = []
    in_tokens = out_tokens = 0
    for turn in range(max_turns):
        try:
            r = call_grok(messages)
        except Exception as e:
            return {"variant":variant,"prompt":prompt,"error":str(e)[:200]}
        usage = r.get("usage",{})
        in_tokens += usage.get("prompt_tokens",0)
        out_tokens += usage.get("completion_tokens",0)
        msg = r["choices"][0]["message"]
        tcs = msg.get("tool_calls") or []
        if not tcs:
            wall = time.time() - t0
            content = msg.get("content","") or ""
            uses_pilot = any("pilot-ask" in c or "pilotctl" in c for c in bash_calls)
            announced = bool(re.search(r"(no specialist|fall(?:ing)? back|fallback)", content, re.I))
            return {
                "variant":variant,"prompt":prompt,"wall":wall,"turns":turn+1,
                "pilot_first":pilot_first,"bash_calls":bash_calls,
                "uses_pilot":uses_pilot,"announced_fallback":announced,
                "answer":content[:500],
                "in_tokens":in_tokens,"out_tokens":out_tokens,
            }
        # execute tool calls; feed results back
        messages.append(msg)
        for tc in tcs:
            try:
                cmd = json.loads(tc["function"]["arguments"]).get("command","")
            except Exception:
                cmd = "(parse_error)"
            if pilot_first is None:
                pilot_first = bool(re.search(r"\bpilot-ask\b|\bpilotctl\b", cmd))
            bash_calls.append(cmd[:100])
            output = exec_bash(cmd)
            messages.append({"role":"tool","tool_call_id":tc["id"],"content":output[:2500]})
    # max_turns hit
    wall = time.time() - t0
    return {"variant":variant,"prompt":prompt,"wall":wall,"turns":max_turns,
            "pilot_first":pilot_first,"bash_calls":bash_calls,
            "uses_pilot":False,"announced_fallback":False,
            "answer":"<truncated at max_turns>",
            "in_tokens":in_tokens,"out_tokens":out_tokens}

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--reps", type=int, default=2)
    p.add_argument("--workers", type=int, default=4)
    p.add_argument("--out", default="/tmp/pilot-tests/benchmark.jsonl")
    args = p.parse_args()

    jobs = []
    for variant in ["OFF","ON"]:
        for rep in range(args.reps):
            for prompt in PROMPTS:
                jobs.append((variant, rep, prompt))
    print(f"Submitting {len(jobs)} agent-loop trials", file=sys.stderr)
    out = open(args.out,"w")
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(run_trial, v, p): (v,r,p) for (v,r,p) in jobs}
        for i,f in enumerate(as_completed(futs),1):
            r = f.result()
            out.write(json.dumps(r)+"\n"); out.flush()
            results.append(r)
            if "error" in r:
                sys.stderr.write(f"\n[{i}/{len(jobs)}] ERROR {r['variant']:3} {r['error'][:60]}\n")
            else:
                sys.stderr.write(f"\n[{i}/{len(jobs)}] {r['variant']:3} pf={r['pilot_first']!s:5} t={r['wall']:5.1f}s turns={r['turns']} announced={r['announced_fallback']!s:5}")
            sys.stderr.flush()
    out.close()
    print()

    # Aggregate
    from collections import defaultdict
    agg = defaultdict(list)
    for r in results:
        if "error" in r: continue
        agg[r["variant"]].append(r)
    print()
    print(f'{"variant":4} {"n":>3} {"wall(med)":>9} {"wall(p90)":>10} {"in_tok(med)":>11} {"out_tok(med)":>12} {"pilot_first":>11} {"announced":>9}')
    for v, lst in sorted(agg.items()):
        n = len(lst)
        walls = sorted(r["wall"] for r in lst)
        med = walls[len(walls)//2]; p90 = walls[int(len(walls)*0.9)]
        in_med = sorted(r["in_tokens"] for r in lst)[n//2]
        out_med = sorted(r["out_tokens"] for r in lst)[n//2]
        pf = sum(1 for r in lst if r["pilot_first"]) / n * 100
        ann = sum(1 for r in lst if r["announced_fallback"]) / n * 100
        print(f'{v:4} {n:>3} {med:>9.2f} {p90:>10.2f} {in_med:>11} {out_med:>12} {pf:>10.1f}% {ann:>8.1f}%')

if __name__ == "__main__":
    main()
