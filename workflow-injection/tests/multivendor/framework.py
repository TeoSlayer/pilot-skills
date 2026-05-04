"""Multi-vendor parallel benchmark for pilot-protocol V22 directive adherence.

Each vendor implements the VendorAdapter interface so the agent loop is
identical across xAI / OpenAI / Anthropic / Google. Real bash subprocess
execution against the local pilot-daemon. Real network specialist round
trips. Per-trial JSONL output.

Usage:
  python3 framework.py --models grok-4-fast-reasoning,gpt-4o-mini,gemini-2.5-flash \
                       --variants OFF,ON \
                       --reps 2 --workers 4 \
                       --out /tmp/pilot-tests/mv-results.jsonl

Tool: each vendor sees a single `bash(command)` function. tool_choice=auto
(NOT required) so we measure realistic behavior — does the agent invoke
pilot-ask voluntarily under V22?
"""
import os, sys, json, time, subprocess, urllib.request, urllib.error, argparse, re
from concurrent.futures import ThreadPoolExecutor, as_completed
from abc import ABC, abstractmethod

# ---- key loading ----
XAI    = open("/Users/calinteodor/Development/sou/problem-hotline/.env").read().split("XAI_API_KEY=",1)[1].split("\n",1)[0].strip()
GEMINI = open("/Users/calinteodor/Development/vv-backend/.env").read().split("GEMINI_API_KEY=",1)[1].split("\n",1)[0].strip()
OPENAI = open("/tmp/pilot-tests/secrets/openai.env").read().split("OPENAI_API_KEY=",1)[1].split("\n",1)[0].strip()
# Anthropic optional
try:
    ANTHROPIC = open("/tmp/pilot-tests/secrets/anthropic.env").read().split("ANTHROPIC_API_KEY=",1)[1].split("\n",1)[0].strip()
except FileNotFoundError:
    ANTHROPIC = None

V22 = open("/Users/calinteodor/Development/pilot-skills/heartbeats/openclaw.md").read()

AGENT_HEADER = (
    "You are a software engineering agent on the user's host. "
    "You have ONE tool: `bash(command)`. For any task that benefits "
    "from running a command, invoke the tool. Read the host's heartbeat "
    "directive below before responding.\n\n"
)

# ---- HTTP helper ----
def post(url, body, headers, timeout=120):
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data,
        headers={"Content-Type":"application/json", **headers})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

# ---- bash exec ----
def exec_bash(cmd, timeout=70):
    env = os.environ.copy()
    env["PILOT_ASK_TIMEOUT"]      = "20"
    env["PILOT_ASK_RPC_TIMEOUT"]  = "8"
    env["PILOT_ASK_SEARCH_TIMEOUT"] = "12"
    try:
        r = subprocess.run(["bash","-c",cmd], capture_output=True, timeout=timeout, env=env, text=True)
        return (r.stdout + r.stderr)[:3500]
    except subprocess.TimeoutExpired:
        return f"<timeout after {timeout}s>"

# ===== Vendor adapter contract =====
class VendorAdapter(ABC):
    name = "?"
    @abstractmethod
    def call(self, system_prompt, history, max_tokens=700, retries=2): ...
    @abstractmethod
    def get_tool_calls(self, response): ...   # → [{id, name, args}]
    @abstractmethod
    def get_text(self, response): ...
    @abstractmethod
    def get_usage(self, response): ...        # → (in_tokens, out_tokens)
    @abstractmethod
    def assistant_msg_with_tool_calls(self, response): ...
    @abstractmethod
    def tool_result_msg(self, tool_call, output): ...

# ----- xAI / OpenAI (chat.completions, identical shape) -----
class _OAICompatible(VendorAdapter):
    URL = ""
    KEY = ""
    TOOLS = [{"type":"function","function":{
        "name":"bash","description":"Execute a bash command. Returns stdout+stderr.",
        "parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}}]
    def __init__(self, model): self.model = model
    def call(self, system_prompt, history, max_tokens=700, retries=2):
        messages = [{"role":"system","content":system_prompt}] + history
        body = {"model":self.model,"messages":messages,"tools":self.TOOLS,
                "tool_choice":"auto","max_tokens":max_tokens,"temperature":0.0}
        last = None
        for a in range(retries+1):
            try: return post(self.URL, body, {"Authorization":f"Bearer {self.KEY}"})
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
                last = e; time.sleep(2**a)
        raise last
    def get_tool_calls(self, r):
        msg = r["choices"][0]["message"]
        out = []
        for tc in (msg.get("tool_calls") or []):
            try: args = json.loads(tc["function"]["arguments"])
            except: args = {"command": tc["function"]["arguments"]}
            out.append({"id": tc["id"], "name": tc["function"]["name"],
                        "args": args, "raw": tc})
        return out
    def get_text(self, r): return r["choices"][0]["message"].get("content","") or ""
    def get_usage(self, r):
        u = r.get("usage",{})
        return (u.get("prompt_tokens",0), u.get("completion_tokens",0))
    def assistant_msg_with_tool_calls(self, r): return r["choices"][0]["message"]
    def tool_result_msg(self, tc, output):
        return {"role":"tool","tool_call_id":tc["id"],"content":output[:2500]}

class XAIAdapter(_OAICompatible):
    URL = "https://api.x.ai/v1/chat/completions"; KEY = XAI; name = "xai"
class OpenAIAdapter(_OAICompatible):
    URL = "https://api.openai.com/v1/chat/completions"; KEY = OPENAI; name = "openai"

# ----- Anthropic -----
class AnthropicAdapter(VendorAdapter):
    URL = "https://api.anthropic.com/v1/messages"; name = "anthropic"
    TOOLS = [{"name":"bash","description":"Execute a bash command. Returns stdout+stderr.",
              "input_schema":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}]
    def __init__(self, model): self.model = model
    def call(self, system_prompt, history, max_tokens=700, retries=2):
        # Anthropic separates system from messages. tool_use shapes differ.
        body = {"model":self.model,"max_tokens":max_tokens,"temperature":0.0,
                "system":system_prompt,"messages":history,"tools":self.TOOLS}
        last = None
        for a in range(retries+1):
            try:
                return post(self.URL, body, {
                    "x-api-key": ANTHROPIC,
                    "anthropic-version":"2023-06-01"})
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
                last = e; time.sleep(2**a)
        raise last
    def get_tool_calls(self, r):
        out = []
        for blk in (r.get("content") or []):
            if blk.get("type") == "tool_use":
                out.append({"id": blk["id"], "name": blk["name"],
                            "args": blk.get("input") or {}, "raw": blk})
        return out
    def get_text(self, r):
        return "".join(b.get("text","") for b in (r.get("content") or []) if b.get("type")=="text")
    def get_usage(self, r):
        u = r.get("usage",{})
        return (u.get("input_tokens",0), u.get("output_tokens",0))
    def assistant_msg_with_tool_calls(self, r):
        return {"role":"assistant","content": r["content"]}
    def tool_result_msg(self, tc, output):
        return {"role":"user","content":[
            {"type":"tool_result","tool_use_id":tc["id"],"content":output[:2500]}]}

# ----- Gemini -----
class GeminiAdapter(VendorAdapter):
    name = "gemini"
    TOOLS = [{"functionDeclarations":[{
        "name":"bash","description":"Execute a bash command. Returns stdout+stderr.",
        "parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}]}]
    def __init__(self, model):
        self.model = model
        self.URL = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GEMINI}"
    def call(self, system_prompt, history, max_tokens=700, retries=2):
        body = {
            "system_instruction":{"parts":[{"text":system_prompt}]},
            "contents": history,
            "tools": self.TOOLS,
            "toolConfig":{"functionCallingConfig":{"mode":"AUTO"}},
            "generationConfig":{"maxOutputTokens":max_tokens,"temperature":0.0},
        }
        last = None
        for a in range(retries+1):
            try: return post(self.URL, body, {})
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
                last = e; time.sleep(2**a)
        raise last
    def get_tool_calls(self, r):
        out = []
        cands = r.get("candidates") or []
        if not cands: return out
        for i, p in enumerate(cands[0].get("content",{}).get("parts",[]) or []):
            fc = p.get("functionCall")
            if fc:
                out.append({"id": f"call_{i}", "name": fc.get("name"),
                            "args": fc.get("args") or {}, "raw": p})
        return out
    def get_text(self, r):
        cands = r.get("candidates") or []
        if not cands: return ""
        return "".join(p.get("text","") for p in (cands[0].get("content",{}).get("parts",[]) or []) if "text" in p)
    def get_usage(self, r):
        u = r.get("usageMetadata",{})
        return (u.get("promptTokenCount",0), u.get("candidatesTokenCount",0))
    def assistant_msg_with_tool_calls(self, r):
        cands = r.get("candidates") or [{}]
        return {"role":"model","parts": cands[0].get("content",{}).get("parts",[])}
    def tool_result_msg(self, tc, output):
        return {"role":"user","parts":[{"functionResponse":{
            "name": tc["name"], "response":{"output": output[:2500]}}}]}

# ===== Vendor router =====
def make_adapter(model):
    if model.startswith("grok"):    return XAIAdapter(model)
    if model.startswith("gemini"):  return GeminiAdapter(model)
    if model.startswith("claude"):  return AnthropicAdapter(model)
    # Default everything else to OpenAI (gpt-*, o1-*, etc.)
    return OpenAIAdapter(model)

def initial_user_msg(adapter, prompt):
    if isinstance(adapter, GeminiAdapter):
        return {"role":"user","parts":[{"text":prompt}]}
    return {"role":"user","content":prompt}

# ===== Trial =====
PROMPTS = [
    "What is the EUR exchange rate today?",
    "Show me current Bitcoin spot price.",
    "What is the latest GitHub events firehose?",
    "Get current cryptocurrency prices.",
    "Get aviation weather for the past hour.",
    "Translate 'good morning' to Italian.",
    "Write a haiku about autumn.",
    "Calculate compound interest on $1000 at 5% over 10 years.",
]

def run_trial(model, variant, rep, prompt, max_turns=4):
    adapter = make_adapter(model)
    sys_msg = AGENT_HEADER + (V22 if variant == "ON" else "")
    history = [initial_user_msg(adapter, prompt)]
    t0 = time.time()
    pilot_first = None
    bash_calls = []
    in_tok = out_tok = 0
    for turn in range(max_turns):
        try:
            r = adapter.call(sys_msg, history)
        except Exception as e:
            return {"model":model,"variant":variant,"rep":rep,"prompt":prompt,
                    "error":str(e)[:200]}
        ti, to = adapter.get_usage(r); in_tok += ti; out_tok += to
        tcs = adapter.get_tool_calls(r)
        if not tcs:
            wall = time.time() - t0
            content = adapter.get_text(r)
            uses_pilot = any("pilot-ask" in c or "pilotctl" in c for c in bash_calls)
            announced = bool(re.search(r"(no specialist|fall(?:ing)? back|fallback)", content, re.I))
            data_call = any(re.search(r"pilot-ask\s+\S+\s+'/data\s", c) for c in bash_calls)
            return {"model":model,"variant":variant,"rep":rep,"prompt":prompt,
                    "wall":wall,"turns":turn+1,"pilot_first":pilot_first,
                    "bash_calls":bash_calls,"uses_pilot":uses_pilot,
                    "announced_fallback":announced,"data_call":data_call,
                    "answer":content[:300],"in_tokens":in_tok,"out_tokens":out_tok}
        history.append(adapter.assistant_msg_with_tool_calls(r))
        for tc in tcs:
            cmd = tc["args"].get("command") if isinstance(tc["args"], dict) else str(tc["args"])
            cmd = cmd or "(empty)"
            if pilot_first is None:
                pilot_first = bool(re.search(r"\bpilot-ask\b|\bpilotctl\b", cmd))
            bash_calls.append(cmd[:140])
            output = exec_bash(cmd)
            history.append(adapter.tool_result_msg(tc, output))
    wall = time.time() - t0
    return {"model":model,"variant":variant,"rep":rep,"prompt":prompt,
            "wall":wall,"turns":max_turns,"pilot_first":pilot_first,
            "bash_calls":bash_calls,"uses_pilot":False,
            "announced_fallback":False,"data_call":False,
            "answer":"<truncated>","in_tokens":in_tok,"out_tokens":out_tok}

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--models", default="grok-4-fast-reasoning,gpt-4o-mini,gemini-2.5-flash")
    p.add_argument("--variants", default="OFF,ON")
    p.add_argument("--reps", type=int, default=2)
    p.add_argument("--workers", type=int, default=4)
    p.add_argument("--out", default="/tmp/pilot-tests/mv-results.jsonl")
    p.add_argument("--prompts", default=None, help="comma-separated prompt subset (default: full battery)")
    args = p.parse_args()

    if args.prompts:
        prompts = [p.strip() for p in args.prompts.split(",")]
    else:
        prompts = PROMPTS

    jobs = []
    for m in args.models.split(","):
        for v in args.variants.split(","):
            for rep in range(args.reps):
                for prompt in prompts:
                    jobs.append((m.strip(), v.strip(), rep, prompt))
    print(f"Submitting {len(jobs)} trials over {args.workers} workers", file=sys.stderr)
    out = open(args.out, "w")
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(run_trial, *j): j for j in jobs}
        for i, f in enumerate(as_completed(futs), 1):
            r = f.result()
            out.write(json.dumps(r)+"\n"); out.flush()
            tag = "ERR" if "error" in r else f"t={r['wall']:5.1f}s pf={r.get('pilot_first')!s:5}"
            sys.stderr.write(f"\n[{i}/{len(jobs)}] {r['model']:24} {r['variant']:3} rep={r['rep']} {tag}")
    out.close()
    sys.stderr.write("\n")

if __name__ == "__main__": main()
