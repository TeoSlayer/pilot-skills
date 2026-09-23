#!/usr/bin/env python3
"""Lint the agent-facing instructions this repo ships.

The heartbeat templates, ONBOARDING.md (-> skills/pilotctl/SKILL.md) and the
curated skills are injected into every agent harness on a Pilot host, so a
wrong recipe here is executed by agents at scale. Each rule below guards a
failure that was reproduced in the field:

  inbox-newest-file  `ls -t ~/.pilot/inbox ... | head -1` style reads. After a
                     failed send they return an old reply (often to another
                     query) as fresh data; the readiness check reported
                     "overlay online" while the node was offline.
  race-claim         "--wait ... so the read can't race" — false.
  send-then-inbox    `send-message` without --wait, immediately followed by an
                     inbox read: reads the inbox before the reply exists.
  appstore-force     `appstore install ... --force` as a routine step: the
                     forced reinstall deletes the app's saved state (keys).
  wait-30            "wait 30 seconds" after install: the daemon rescans every
                     2 s; the comment wastes ~28 s per install.
  privacy-claim      "nothing ... is logged, scored, or reported anywhere" /
                     "Pilot does not observe or record": false (app-store
                     telemetry is on by default; pilot-mom logs tasks).
  heartbeat-template skillinject renders heartbeats with text/template and
                     splices them with regexp.ReplaceAllString, so `$1`,
                     `$5`, `${x}` and `$VAR` are expanded (to nothing) and
                     `{{` starts a template action.
  jq-envelope        a jq filter fed directly by `pilotctl --json <cmd>` must
                     run against the real `{"status":"ok","data":{...}}`
                     output of <cmd> (tests/fixtures/pilotctl/<cmd>.json)
                     without a jq error or an all-null result, and must not be
                     written for the unwrapped shape (reading `.field` instead
                     of `.data.field`).

jq-envelope is enforced for the injected set (heartbeats, ONBOARDING.md,
skills/pilotctl and every skill in inject-manifest.json referencedSkills) and
reported as a warning for the other skills. Everything else is enforced
everywhere it is checked.

Usage:  lint_agent_instructions.py [--self-test]
Exit status: 0 clean, 1 findings, 2 usage/environment error.
"""

import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "tests" / "fixtures" / "pilotctl"

# Paths other in-flight work owns. Remove an entry once that work lands and
# the path passes this lint.
#   skills/pilot-sandbox/ — still reads the newest inbox file (SKILL.md
#   "Workflow Example"); owned by the muse one-shot-install branch.
EXCLUDED_PREFIXES = ("muse/", "skills/pilot-sandbox/", "workflow-injection/tests/")

# Commands whose second word is part of the command name.
SUBCOMMAND_GROUPS = {"extras", "appstore", "daemon", "skills", "network", "update", "updates", "task"}


def rel(p):
    return p.resolve().relative_to(ROOT).as_posix()


def excluded(relpath):
    return relpath.startswith(EXCLUDED_PREFIXES)


def all_docs():
    files = []
    files += sorted(ROOT.glob("heartbeats/*.md"))
    files += [ROOT / "ONBOARDING.md", ROOT / "README.md", ROOT / "CONTRIBUTING.md"]
    files += sorted(ROOT.glob("workflow-injection/*.md"))
    files += sorted(ROOT.glob("skills/**/*.md"))
    return [f for f in files if f.is_file() and not excluded(rel(f))]


def injected_docs():
    out = set(rel(f) for f in ROOT.glob("heartbeats/*.md"))
    out.update({"ONBOARDING.md", "skills/pilotctl/SKILL.md"})
    manifest = json.loads((ROOT / "inject-manifest.json").read_text())
    for url in manifest.get("referencedSkills", []):
        m = re.match(r"^https?://github\.com/[^/]+/[^/]+/blob/[^/]+/(.+)$", url)
        if m and not excluded(m.group(1)):
            out.add(m.group(1))
    return out


# ---------------------------------------------------------------- text rules

TEXT_RULES = [
    ("inbox-newest-file",
     re.compile(r"\bls\s+-[A-Za-z0-9]*t[A-Za-z0-9]*\b[^|\n]*\.pilot/inbox"),
     "reads 'the newest inbox file'; use the reply printed by "
     "`pilotctl --json send-message X --data ... --wait` (data.reply) and its exit status"),
    ("race-claim",
     re.compile(r"\b(can'?t|cannot|can not|won'?t)\s+race\b", re.I),
     "claims the inbox read cannot race; it can (--wait matches by sender and time only)"),
    ("appstore-force",
     re.compile(r"appstore\s+install\b[^\n`|;]*\s--force\b"),
     "routine `appstore install --force` deletes the app's saved state; install once, then call"),
    ("wait-30",
     re.compile(r"\bwait 30 seconds\b", re.I),
     "stale 'wait 30 seconds' after install; the daemon picks apps up within seconds"),
    ("privacy-claim",
     re.compile(r"logged, scored, or reported|does not observe or record|cannot observe", re.I),
     "false privacy claim; app-store telemetry is on by default and service agents may log queries"),
]


def check_text(relpath, text, findings):
    for lineno, line in enumerate(text.split("\n"), 1):
        for name, rx, msg in TEXT_RULES:
            if rx.search(line):
                findings.append(("FAIL", relpath, lineno, name, msg))


SEND_NO_WAIT = re.compile(r"\bpilotctl\b.*\bsend-message\b")
INBOX_READ = re.compile(r"\bpilotctl\b.*\binbox\b")
SLEEP_LINE = re.compile(r"^\s*sleep\s+\d+\s*$")


def logical_lines(text):
    """(lineno, line) pairs with `\\` continuations joined onto their first line."""
    out, buf, start = [], [], 0
    for lineno, line in enumerate(text.split("\n"), 1):
        if not buf:
            start = lineno
        if line.rstrip().endswith("\\"):
            buf.append(line.rstrip()[:-1])
            continue
        buf.append(line)
        out.append((start, " ".join(buf)))
        buf = []
    if buf:
        out.append((start, " ".join(buf)))
    return out


def check_send_then_inbox(relpath, text, findings):
    lines = logical_lines(text)
    for i, (lineno, line) in enumerate(lines):
        if not SEND_NO_WAIT.search(line) or "--wait" in line:
            continue
        j = i + 1
        while j < len(lines) and SLEEP_LINE.match(lines[j][1]):
            j += 1
        if j < len(lines) and INBOX_READ.search(lines[j][1]):
            findings.append(("FAIL", relpath, lineno, "send-then-inbox",
                             "send-message without --wait followed by an inbox read; "
                             "add --wait and read data.reply from the send's own output"))


TEMPLATE_ACTION = re.compile(r"\{\{.*?\}\}", re.S)


def check_heartbeat_template(relpath, text, findings):
    for lineno, line in enumerate(text.split("\n"), 1):
        if "$" in line:
            findings.append(("FAIL", relpath, lineno, "heartbeat-template",
                             "`$` in a heartbeat template: skillinject's ReplaceAllString expands "
                             "`$1`/`$VAR`/`${x}` to nothing (write 'USD 5', avoid shell variables)"))
    for m in TEMPLATE_ACTION.finditer(text):
        if m.group(0) != "{{.EntrypointPath}}":
            lineno = text.count("\n", 0, m.start()) + 1
            findings.append(("FAIL", relpath, lineno, "heartbeat-template",
                             "template action %r: heartbeats are rendered with text/template and "
                             "only {{.EntrypointPath}} is defined" % m.group(0)))
    if text.count("{{") != text.count("{{.EntrypointPath}}"):
        findings.append(("FAIL", relpath, 0, "heartbeat-template", "unbalanced or unknown `{{`"))


# -------------------------------------------------------------- jq envelope

FENCE = re.compile(r"^\s*(```|~~~)")
PUNCT = {"|", "||", "&&", ";", "&", "(", ")", "<", ">", ">>", ";;"}


def code_lines(text):
    """Yield (lineno, logical_line) for fenced code, joining `\\` continuations."""
    inside = False
    buf, start = [], 0
    for lineno, line in enumerate(text.split("\n"), 1):
        if FENCE.match(line):
            inside = not inside
            buf = []
            continue
        if not inside:
            continue
        if not buf:
            start = lineno
        if line.rstrip().endswith("\\"):
            buf.append(line.rstrip()[:-1])
            continue
        buf.append(line)
        yield start, " ".join(buf)
        buf = []


def tokenize(line):
    lex = shlex.shlex(line, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = "#"
    return list(lex)


def pipelines(line):
    """Yield (command, jq_options, jq_filter) for `pilotctl --json CMD ... | jq ...`."""
    try:
        toks = tokenize(line)
    except ValueError:
        return
    for i, tok in enumerate(toks):
        if tok != "pilotctl" and not tok.endswith("/pilotctl"):
            continue
        j = i + 1
        words = []
        while j < len(toks) and toks[j] not in PUNCT:
            words.append(toks[j])
            j += 1
        if "--json" not in words or j + 1 >= len(toks) or toks[j] != "|" or toks[j + 1] != "jq":
            continue
        positional = [w for w in words if not w.startswith("-")]
        if not positional:
            continue
        cmd = positional[0]
        if cmd in SUBCOMMAND_GROUPS and len(positional) > 1:
            cmd = cmd + " " + positional[1]
        k = j + 2
        opts, jq_filter = [], None
        while k < len(toks) and toks[k] not in PUNCT:
            t = toks[k]
            if jq_filter is None and t in ("--arg", "--argjson", "--slurpfile", "--rawfile"):
                opts.append((t, toks[k + 1] if k + 1 < len(toks) else "", toks[k + 2] if k + 2 < len(toks) else ""))
                k += 3
                continue
            if jq_filter is None and t.startswith("-"):
                opts.append((t,))
                k += 1
                continue
            if jq_filter is None:
                jq_filter = t
            k += 1
        if jq_filter is not None:
            yield cmd, opts, jq_filter


def run_jq(jq_filter, opts, doc):
    args = ["jq", "-c"]
    for o in opts:
        flag = o[0]
        if flag in ("--arg",):
            args += ["--arg", o[1], o[2] if "$" not in o[2] else "fixture-value"]
        elif flag == "--argjson":
            val = o[2]
            try:
                json.loads(val)
            except ValueError:
                val = "1"
            args += ["--argjson", o[1], val]
        elif flag in ("--slurpfile", "--rawfile"):
            return None  # file inputs: not a pure function of the pilotctl output
        elif re.fullmatch(r"-[a-zA-Z]+", flag):
            # keep -s/-n style input modes; drop output-only flags (-r, -e, -c, -j, -M)
            keep = "".join(ch for ch in flag[1:] if ch in "sn")
            if keep:
                args.append("-" + keep)
    args.append(jq_filter)
    p = subprocess.run(args, input=json.dumps(doc), capture_output=True, text=True)
    if p.returncode != 0:
        return ("error", p.stderr.strip().splitlines()[-1] if p.stderr.strip() else "jq error")
    values = [json.loads(v) for v in p.stdout.split("\n") if v.strip()]
    return ("ok", values)


def degenerate(result):
    """True when a jq result carries no information: error, empty, or only null/false/all-null objects."""
    if result[0] == "error":
        return True
    vals = result[1]
    if not vals:
        return True
    def empty(v):
        if v is None or v is False:
            return True
        if isinstance(v, dict):
            return all(empty(x) for x in v.values())
        return False
    return all(empty(v) for v in vals)


def check_jq(relpath, text, enforced, findings):
    for lineno, line in code_lines(text):
        for cmd, opts, jq_filter in pipelines(line):
            if jq_filter.strip() == ".":
                continue
            level = "FAIL" if enforced else "WARN"
            fixture = FIXTURES / (cmd.replace(" ", "-") + ".json")
            if not fixture.is_file():
                if enforced:
                    findings.append((level, relpath, lineno, "jq-envelope",
                                     "no fixture for `pilotctl --json %s` in tests/fixtures/pilotctl/; "
                                     "add its real output so this recipe can be checked" % cmd))
                continue
            wrapped = json.loads(fixture.read_text())
            got = run_jq(jq_filter, opts, wrapped)
            if got is None:
                continue
            if got[0] == "error":
                findings.append((level, relpath, lineno, "jq-envelope",
                                 "jq %r fails on real `pilotctl --json %s` output: %s" % (jq_filter, cmd, got[1])))
                continue
            if got[1] and degenerate(got):
                findings.append((level, relpath, lineno, "jq-envelope",
                                 "jq %r yields only null on real `pilotctl --json %s` output "
                                 "(fields live under .data)" % (jq_filter, cmd)))
                continue
            unwrapped = run_jq(jq_filter, opts, wrapped.get("data"))
            if unwrapped is not None and not degenerate(unwrapped) and unwrapped[1] != got[1]:
                findings.append((level, relpath, lineno, "jq-envelope",
                                 "jq %r is written for the unwrapped shape of `pilotctl --json %s`; "
                                 "read through .data" % (jq_filter, cmd)))


# ------------------------------------------------------------------- driver

def lint(files, injected):
    findings = []
    for f in files:
        relpath = rel(f)
        text = f.read_text()
        check_text(relpath, text, findings)
        check_send_then_inbox(relpath, text, findings)
        if relpath.startswith("heartbeats/"):
            check_heartbeat_template(relpath, text, findings)
        check_jq(relpath, text, relpath in injected, findings)
    return findings


SELF_TEST_BAD = {
    "inbox-newest-file": 'jq -r \'.data\' "$(ls -1t ~/.pilot/inbox/*.json | head -1)"\n',
    "race-claim": "`--wait` blocks until the reply lands, so the read can't race.\n",
    "send-then-inbox": (
        "```bash\npilotctl --json send-message list-agents --data '/help'\nsleep 5\npilotctl --json inbox\n"
        "pilotctl --json send-message x \\\n  --data '/data {}'\npilotctl --json inbox\n```\n"
    ),
    "appstore-force": "pilotctl appstore install io.pilot.smol --force\n",
    "wait-30": "pilotctl appstore install io.pilot.smol # wait 30 seconds for daemon to spawn app\n",
    "privacy-claim": "nothing about which tool you pick is logged, scored, or reported anywhere.\n",
    "heartbeat-template": "metered against a per-user **$5 budget** {{.Other}}\n",
    "jq-envelope": (
        "```bash\n"
        "pilotctl --json find agent-prod-1 | jq '.[0]'\n"
        "pilotctl --json info | jq -r '.encrypted_peers // 0'\n"
        "pilotctl --json info | jq '{hostname, address}'\n"
        "pilotctl --json pending | jq -r '.[] | select(.address | startswith(\"1:\")) | .node_id'\n"
        "```\n"
    ),
}
SELF_TEST_GOOD = (
    "Never add `--force` to `install`; `pilotctl --json inbox --from x --since 5m --latest`.\n"
    "```bash\n"
    "pilotctl --json send-message list-agents --data '/data {\"search\":\"\",\"limit\":1}' --wait\n"
    "pilotctl --json send-message x --data '/help' --wait | jq -e -r '.data.reply.data | fromjson | .total'\n"
    "pilotctl --json find agent-prod-1 | jq '.data | {hostname, address, node_id, public}'\n"
    "pilotctl --json lookup \"$ID\" | jq -r --arg t \"$T\" 'select(any(.data.tags[]?; . == $t)) | .data.hostname'\n"
    "pilotctl --json lookup \"$ID\" | jq -e 'any(.data.networks[]?; . == 1)' >/dev/null\n"
    "pilotctl --json ping a --count 1 | jq -e '[.data.results[] | select(.rtt_ms != null)] | length > 0'\n"
    "pilotctl --json info | jq -r '.data.encrypted_peers'\n"
    "pilotctl --json pending | jq -r '.data.pending[].node_id'\n"
    "```\n"
    "per-user **USD 5 budget** — see {{.EntrypointPath}}\n"
)


def self_test():
    failures = 0
    for rule, sample in SELF_TEST_BAD.items():
        findings = []
        relpath = "heartbeats/self-test.md" if rule == "heartbeat-template" else "skills/self-test/SKILL.md"
        check_text(relpath, sample, findings)
        check_send_then_inbox(relpath, sample, findings)
        if rule == "heartbeat-template":
            check_heartbeat_template(relpath, sample, findings)
        check_jq(relpath, sample, True, findings)
        hits = [f for f in findings if f[3] == rule]
        want = {"jq-envelope": 4, "send-then-inbox": 2}.get(rule, 1)  # broken recipes per sample
        if len(hits) < want:
            print("self-test FAIL: rule %s flagged %d of %d bad samples" % (rule, len(hits), want))
            for f in findings:
                print("   ", f)
            failures += 1
    findings = []
    check_text("heartbeats/self-test.md", SELF_TEST_GOOD, findings)
    check_send_then_inbox("heartbeats/self-test.md", SELF_TEST_GOOD, findings)
    check_jq("heartbeats/self-test.md", SELF_TEST_GOOD, True, findings)
    good_tpl = "per-user **USD 5 budget** — see {{.EntrypointPath}}\n"
    check_heartbeat_template("heartbeats/self-test.md", good_tpl, findings)
    if findings:
        print("self-test FAIL: good sample was flagged:")
        for f in findings:
            print("   ", f)
        failures += 1
    print("self-test: %s" % ("PASS" if not failures else "%d failure(s)" % failures))
    return 1 if failures else 0


def main():
    if shutil.which("jq") is None:
        print("lint_agent_instructions: jq is required (apt-get install jq / brew install jq)", file=sys.stderr)
        return 2
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if sys.argv[1:]:
        print(__doc__, file=sys.stderr)
        return 2
    findings = lint(all_docs(), injected_docs())
    fails = [f for f in findings if f[0] == "FAIL"]
    warns = [f for f in findings if f[0] == "WARN"]
    for level, path, lineno, rule, msg in fails:
        print("FAIL: %s:%d: [%s] %s" % (path, lineno, rule, msg))
    if warns:
        files = sorted(set(f[1] for f in warns))
        print("WARN: %d jq recipe(s) in %d non-injected skill(s) do not match real `pilotctl --json` output "
              "(not enforced yet): %s" % (len(warns), len(files), ", ".join(files)))
        if os.environ.get("LINT_VERBOSE"):
            for level, path, lineno, rule, msg in warns:
                print("WARN: %s:%d: [%s] %s" % (path, lineno, rule, msg))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
