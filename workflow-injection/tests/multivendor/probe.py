import os, json, urllib.request, urllib.error

XAI    = open("/Users/calinteodor/Development/sou/problem-hotline/.env").read().split("XAI_API_KEY=",1)[1].split("\n",1)[0]
GEMINI = open("/Users/calinteodor/Development/vv-backend/.env").read().split("GEMINI_API_KEY=",1)[1].split("\n",1)[0].strip()
OPENAI = open("/tmp/pilot-tests/secrets/openai.env").read().split("OPENAI_API_KEY=",1)[1].split("\n",1)[0].strip()

def post(url, body, headers):
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type":"application/json", **headers})
    with urllib.request.urlopen(req, timeout=30) as r: return r.status, json.loads(r.read())

TOOL_OAI = {"type":"function","function":{"name":"bash","description":"Run a bash cmd","parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}}

print("xAI grok-4-fast-reasoning:", end=" ", flush=True)
try:
    s,r = post("https://api.x.ai/v1/chat/completions",
        {"model":"grok-4-fast-reasoning","messages":[{"role":"user","content":"echo hi via bash"}],"tools":[TOOL_OAI],"tool_choice":"auto","max_tokens":80},
        {"Authorization":f"Bearer {XAI}"})
    msg = r["choices"][0]["message"]; print("ok tool_calls=", "tool_calls" in msg)
except urllib.error.HTTPError as e: print("HTTP", e.code, e.read()[:200])

print("OpenAI gpt-4o-mini:", end=" ", flush=True)
try:
    s,r = post("https://api.openai.com/v1/chat/completions",
        {"model":"gpt-4o-mini","messages":[{"role":"user","content":"echo hi via bash"}],"tools":[TOOL_OAI],"tool_choice":"auto","max_tokens":80},
        {"Authorization":f"Bearer {OPENAI}"})
    msg = r["choices"][0]["message"]; print("ok tool_calls=", "tool_calls" in msg)
except urllib.error.HTTPError as e: print("HTTP", e.code, e.read()[:200])

print("Gemini 2.5-flash:", end=" ", flush=True)
try:
    s,r = post(f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI}",
        {
          "contents":[{"role":"user","parts":[{"text":"echo hi via bash"}]}],
          "tools":[{"functionDeclarations":[{"name":"bash","description":"Run a bash cmd","parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}]}],
          "toolConfig":{"functionCallingConfig":{"mode":"AUTO"}},
          "generationConfig":{"maxOutputTokens":80}
        }, {})
    cand = r.get("candidates",[{}])[0]
    parts = cand.get("content",{}).get("parts",[])
    fc = next((p.get("functionCall") for p in parts if p.get("functionCall")), None)
    print("ok function_call=", fc is not None, "parts=", len(parts))
except urllib.error.HTTPError as e: print("HTTP", e.code, e.read()[:300])
