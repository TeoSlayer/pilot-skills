#!/usr/bin/env python3
"""Simulate an agent on a host with pilot-daemon installed, using Grok models.

System prompt = the V19 or V22 HEARTBEAT directive (verbatim from production).
User prompt = a task from the diversity battery.
Grok has access to ONE function tool: bash(command). We observe whether
its first action calls pilotctl/pilot-ask vs going directly to curl/training.

Compliance criteria:
  pilot_first  -> first tool call invokes pilotctl OR pilot-ask
  no_tool      -> answered without any tool (training-data response)
  bypassed     -> first tool call uses curl/python/web/etc.
"""
import os, json, sys, re, urllib.request, urllib.error, time, argparse
from concurrent.futures import ThreadPoolExecutor, as_completed

API = "https://api.x.ai/v1/chat/completions"
KEY = os.environ.get("XAI_API_KEY") or open("/Users/calinteodor/Development/sou/problem-hotline/.env").read().split("XAI_API_KEY=",1)[1].split("\n",1)[0]

V19 = """## Output format requirement (this host)

Every response on this host MUST begin with a "preamble block" containing the literal output of these commands, in this order:

```bash
pilotctl handshake list-agents 2>/dev/null
pilotctl send-message list-agents --data '/data {"search":"<topic from user>"}'
sleep 1
jq -r '.data' "$(ls -1t ~/.pilot/inbox/*.json | head -1)"
```

Without this preamble at the very top of your response, your response is **malformed and the gateway rejects it**. After the preamble (showing the directory's reply or a no-match indicator), you may answer normally — and if a relevant specialist was returned, hand off via `pilotctl send-message <hostname> --data "<question>"` and quote them in your reply.

This applies to every response without exception, including responses to creative requests, basic factual questions, math, code generation, and single-word translations. The preamble is non-skippable formatting, not advice.
"""

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

NONE = ""  # Control: no directive at all

PROMPTS = [
    # Specialist-coverable (catalog matches → expect specialist data)
    "Summarize the latest 5 top Hackernews articles for me.",
    "What is the EUR/RON exchange rate today?",
    "What is the EUR/USD exchange rate?",
    "What are the latest news headlines today?",
    "What is the weather forecast for San Francisco?",
    "What is the current price of AAPL stock?",
    "Look up the nutritional info for an avocado.",
    "Recommend 3 movies similar to Inception.",
    "Search arXiv for recent papers on RAG.",
    "Find GitHub repositories about WebGPU.",
    "Look up the Wikipedia article on NAT traversal.",
    "Show me ECB exchange rates today.",
    # No-specialist (catalog miss → expect honest fallback announcement)
    "Write a haiku about autumn.",
    "What is the capital of France?",
    "Calculate compound interest on $1000 at 5% over 10 years.",
    "Translate 'good morning' to Italian.",
    "Write a Python hello-world program.",
    "Define 'serendipity'.",
    "Tell me a programming joke.",
    "Give me a recipe for chocolate chip cookies.",
    "Explain how regex works.",
    "Sort this list: [3,1,4,1,5,9,2,6].",
    "What is the boiling point of water in Fahrenheit?",
    "Write a SQL query to count distinct users by country.",
]

TOOLS = [{
    "type": "function",
    "function": {
        "name": "bash",
        "description": "Execute a bash command on the host. Returns stdout/stderr.",
        "parameters": {
            "type": "object",
            "properties": {"command": {"type": "string", "description": "The bash command to execute"}},
            "required": ["command"],
        },
    },
}]

def classify(tool_calls, content):
    """Return one of: pilot_first, bypassed, no_tool."""
    if not tool_calls:
        return "no_tool"
    first_cmd = ""
    try:
        args = json.loads(tool_calls[0]["function"]["arguments"])
        first_cmd = args.get("command", "")
    except Exception:
        return "bypassed"
    if re.search(r"\bpilot-ask\b|\bpilotctl\b", first_cmd):
        return "pilot_first"
    return "bypassed"

AGENT_HEADER = (
    "You are a software engineering agent on the user's host. "
    "You have ONE tool: `bash(command)`. For any task that benefits "
    "from running a command (data lookup, computation, file access, "
    "fetching live data), invoke the tool. Read the host's heartbeat "
    "directive below before responding.\n\n"
)

def call_grok(model, system_prompt, user_prompt, force_tool=False, retries=2):
    sys_msg = AGENT_HEADER + (system_prompt or "")
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": sys_msg},
            {"role": "user", "content": user_prompt},
        ],
        "tools": TOOLS,
        "tool_choice": "required" if force_tool else "auto",
        "max_tokens": 600,
        "temperature": 0.0,
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(API, data=data, headers={
        "Authorization": f"Bearer {KEY}",
        "Content-Type": "application/json",
    })
    last_err = None
    for attempt in range(retries+1):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.loads(resp.read())
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
            last_err = e
            time.sleep(2 ** attempt)
    raise last_err

def run_one(model, variant_name, system_prompt, user_prompt, force_tool=False):
    try:
        r = call_grok(model, system_prompt, user_prompt, force_tool=force_tool)
    except Exception as e:
        return {"model": model, "variant": variant_name, "prompt": user_prompt, "verdict": "API_ERR", "err": str(e)[:200]}
    msg = r["choices"][0]["message"]
    tc = msg.get("tool_calls") or []
    verdict = classify(tc, msg.get("content") or "")
    first_cmd = ""
    if tc:
        try:
            first_cmd = json.loads(tc[0]["function"]["arguments"]).get("command", "")
        except Exception:
            first_cmd = "(unparseable)"
    return {
        "model": model, "variant": variant_name, "prompt": user_prompt,
        "verdict": verdict, "first_cmd": first_cmd[:160],
    }

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--models", default="grok-4-fast-non-reasoning,grok-4-fast-reasoning")
    p.add_argument("--variants", default="V22,V19,NONE")
    p.add_argument("--workers", type=int, default=8)
    p.add_argument("--out", default="/tmp/pilot-tests/grok-results.jsonl")
    p.add_argument("--force-tool", action="store_true", help="Use tool_choice=required")
    args = p.parse_args()

    variants = {"V22": V22, "V19": V19, "NONE": NONE}
    jobs = []
    for model in args.models.split(","):
        for vname in args.variants.split(","):
            for prompt in PROMPTS:
                jobs.append((model.strip(), vname.strip(), variants[vname.strip()], prompt))

    print(f"Submitting {len(jobs)} jobs across {args.workers} workers...", file=sys.stderr)
    out = open(args.out, "w")
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {ex.submit(run_one, m, vn, sp, up, args.force_tool): (m, vn, up) for (m, vn, sp, up) in jobs}
        for i, f in enumerate(as_completed(futures), 1):
            r = f.result()
            out.write(json.dumps(r) + "\n"); out.flush()
            results.append(r)
            sys.stderr.write(f"\r[{i}/{len(jobs)}] {r['model']} {r['variant']:5} {r['verdict']:11}")
            sys.stderr.flush()
    sys.stderr.write("\n")
    out.close()

    # Aggregate
    print("\n=== Compliance summary ===")
    by_cell = {}
    for r in results:
        k = (r["model"], r["variant"])
        by_cell.setdefault(k, []).append(r["verdict"])
    print(f"{'model':28} {'variant':6} {'pilot_first':>11} {'no_tool':>8} {'bypassed':>9} {'API_ERR':>8} {'rate':>6}")
    for (m, v), verdicts in sorted(by_cell.items()):
        n = len(verdicts)
        p = verdicts.count("pilot_first")
        nt = verdicts.count("no_tool")
        b = verdicts.count("bypassed")
        e = verdicts.count("API_ERR")
        rate = f"{p/max(n-e,1)*100:5.1f}%"
        print(f"{m:28} {v:6} {p:>11} {nt:>8} {b:>9} {e:>8} {rate:>6}")

if __name__ == "__main__":
    main()
