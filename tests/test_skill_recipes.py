#!/usr/bin/env python3
"""Run the shell recipes that injected skills tell agents to execute.

tests/lint_agent_instructions.py checks each `pilotctl --json X | jq` filter
on its own. This file runs whole recipe blocks verbatim from the Markdown:
loops, exit statuses, `||` fallbacks and circle files. A stub `pilotctl` on
PATH prints the fixtures in tests/fixtures/pilotctl/ and exits with the same
status as the real pilotctl. HOME is a temporary directory, so nothing touches
the real ~/.pilot.

Usage:  python3 tests/test_skill_recipes.py [-v]
"""

import json
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "tests" / "fixtures" / "pilotctl"

# The stub logs each call (minus --json) and answers from a JSON spec:
#   {"<cmd>": {"fixture": "<file>" | "stdout": "...", "stderr": "...", "rc": N}}
# or, keyed by the command's first argument (with "*" as the fallback):
#   {"<cmd>": {"<arg>": {...}, "*": {...}}}
# A call the spec does not cover fails like pilotctl does: stderr error, exit 1.
STUB = r'''#!/usr/bin/env python3
import json, os, sys
args = [a for a in sys.argv[1:] if a != "--json"]
with open(os.environ["PILOTCTL_STUB_LOG"], "a") as f:
    f.write(json.dumps(args) + "\n")
with open(os.environ["PILOTCTL_STUB"]) as f:
    spec = json.load(f)
entry = spec.get(args[0] if args else "")
if isinstance(entry, dict) and not ({"rc", "stdout", "fixture"} & set(entry)):
    arg = args[1] if len(args) > 1 else ""
    entry = entry.get(arg, entry.get("*"))
if entry is None:
    sys.stderr.write('{"status":"error","code":"not_found","message":"stub: %s"}\n' % " ".join(args))
    sys.exit(1)
out = entry.get("stdout", "")
if "fixture" in entry:
    with open(os.path.join(os.environ["PILOTCTL_FIXTURES"], entry["fixture"])) as f:
        out = f.read()
sys.stdout.write(out)
sys.stderr.write(entry.get("stderr", ""))
sys.exit(entry.get("rc", 0))
'''


def code_block(relpath, heading, lang=None):
    """The first fenced code block after the line `heading` in ROOT/relpath."""
    lines = (ROOT / relpath).read_text().split("\n")
    try:
        i = lines.index(heading)
    except ValueError:
        raise AssertionError("%s: heading %r not found" % (relpath, heading))
    while not lines[i].startswith("```"):
        i += 1
    if lang:
        assert lines[i] == "```" + lang, "%s: block after %r is not ```%s" % (relpath, heading, lang)
    end = lines.index("```", i + 1)
    return "\n".join(lines[i + 1:end]) + "\n"


def lookup_record(hostname, node_id, public_key):
    return {"stdout": json.dumps({"status": "ok", "data": {
        "type": "lookup_ok", "node_id": node_id, "address": "0:0000.0000.%04X" % node_id,
        "networks": [0], "public_key": public_key, "public": True, "hostname": hostname}}) + "\n"}


OK_ENVELOPE = {"stdout": '{"status":"ok","data":{}}\n'}
NOT_FOUND = {"stderr": '{"status":"error","code":"not_found","message":"not found"}\n', "rc": 1}


class Sandbox:
    """A temporary HOME, a stub pilotctl on PATH, and the calls it received."""

    def __init__(self, spec):
        self.tmp = tempfile.TemporaryDirectory()
        base = pathlib.Path(self.tmp.name)
        self.home = base / "home"
        (self.home / ".pilot").mkdir(parents=True)
        bindir = base / "bin"
        bindir.mkdir()
        stub = bindir / "pilotctl"
        stub.write_text(STUB)
        stub.chmod(0o755)
        self.spec_path = base / "spec.json"
        self.spec_path.write_text(json.dumps(spec))
        self.log = base / "calls.log"
        self.log.write_text("")
        self.env = dict(os.environ, HOME=str(self.home), PATH="%s:%s" % (bindir, os.environ["PATH"]),
                        PILOTCTL_STUB=str(self.spec_path), PILOTCTL_STUB_LOG=str(self.log),
                        PILOTCTL_FIXTURES=str(FIXTURES))

    def run(self, script, *args):
        path = pathlib.Path(self.tmp.name) / "recipe.sh"
        path.write_text(script)
        # plain `bash`, no pipefail: the shell an agent's tool call runs in
        return subprocess.run(["bash", str(path)] + list(args), env=self.env,
                              capture_output=True, text=True, timeout=60)

    def calls(self, cmd=None):
        calls = [json.loads(l) for l in self.log.read_text().splitlines() if l.strip()]
        return [c for c in calls if cmd is None or (c and c[0] == cmd)]

    def close(self):
        self.tmp.cleanup()


class RecipeTest(unittest.TestCase):
    def sandbox(self, spec):
        sb = Sandbox(spec)
        self.addCleanup(sb.close)
        return sb


# ------------------------------------------------------------ pilot-verify

PING_OUTCOMES = {
    # name: (spec for `pilotctl ping`, reachable?)
    "healthy": ({"fixture": "ping.json"}, True),
    "echo lost after dial (rtt_ms + error, exit 1)": ({"fixture": "ping.fail-echo-timeout.json", "rc": 1}, False),
    "dial failed (exit 1)": ({"fixture": "ping.fail-dial.json", "rc": 1}, False),
    "overall timeout, every probe failed (exit 0)": ({"fixture": "ping.fail-overall-timeout.json"}, False),
    "daemon down (nothing on stdout, exit 1)": (
        {"stderr": '{"status":"error","code":"connection_failed"}\n', "rc": 1}, False),
}


class PilotVerifyReachability(RecipeTest):
    SKILL = "skills/pilot-verify/SKILL.md"

    def test_check_availability_recipe(self):
        recipe = code_block(self.SKILL, "### Check availability", "bash")
        for name, (ping, reachable) in PING_OUTCOMES.items():
            with self.subTest(name):
                sb = self.sandbox({"ping": ping})
                res = sb.run(recipe)
                said_unreachable = "Agent unreachable" in res.stdout
                self.assertEqual(said_unreachable, not reachable, res.stdout + res.stderr)
                self.assertTrue(sb.calls("ping"))

    def test_workflow_example_step3(self):
        script = code_block(self.SKILL, "## Workflow Example", "bash")
        for name, (ping, reachable) in PING_OUTCOMES.items():
            with self.subTest(name):
                sb = self.sandbox({"lookup": {"fixture": "lookup.json"}, "ping": ping})
                res = sb.run(script, "agent-prod-1")
                if reachable:
                    self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
                    self.assertIn("Status: VERIFIED", res.stdout)
                else:
                    self.assertEqual(res.returncode, 1, res.stdout + res.stderr)
                    self.assertIn("FAILED: Agent unreachable", res.stdout)
                    self.assertNotIn("VERIFIED", res.stdout)


# ------------------------------------------------- send-message --wait reply

def reply_body():
    doc = json.loads((FIXTURES / "send-message.json").read_text())
    return doc["data"]["reply"]["data"]


SEND_OUTCOMES = {
    # name: (spec for `pilotctl send-message`, reply body or None)
    "v1.12.3+: one document, reply folded in": ({"fixture": "send-message.json"}, reply_body()),
    "v1.12.2 and older: send result, then the reply": ({"fixture": "send-message.ok-v1.12.2.json"}, reply_body()),
    "v1.12.2 and older, no reply (send result only, exit 1)": (
        {"fixture": "send-message.fail-v1.12.2-timeout.json",
         "stderr": '{"status":"error","code":"timeout"}\n', "rc": 1}, None),
    "v1.12.3+, no reply (nothing on stdout, exit 1)": (
        {"stderr": '{"status":"error","code":"timeout"}\n', "rc": 1}, None),
}


class SendMessageReplyRecipe(RecipeTest):
    def check(self, relpath):
        recipe = code_block(relpath, "### Step 1.3: Read the reply from the command's output", "sh")
        recipe = recipe.replace("<agent>", "list-agents")
        for name, (send, body) in SEND_OUTCOMES.items():
            with self.subTest(name):
                sb = self.sandbox({"send-message": send})
                res = sb.run(recipe)
                if body is None:
                    self.assertNotEqual(res.returncode, 0, res.stdout)
                    self.assertEqual(res.stdout.strip(), "", "a failed send must print no reply")
                else:
                    self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
                    self.assertEqual(res.stdout.strip(), body)
                    self.assertEqual(json.loads(res.stdout)["total"], 430)

    def test_onboarding(self):
        self.check("ONBOARDING.md")

    def test_generated_pilotctl_skill(self):
        self.check("skills/pilotctl/SKILL.md")


# ------------------------------------------------------ pilot-trust-circle

KEY_ALICE = "YWxpY2UtcHVibGljLWtleS1maXh0dXJlLTAwMDAwMDA="
KEY_BOB = "Ym9iLXB1YmxpYy1rZXktZml4dHVyZS0wMDAwMDAwMDA="
KEY_OTHER = "b3RoZXIta2V5LWZpeHR1cmUtMDAwMDAwMDAwMDAwMDA="


def pending(*entries):
    items = [{"node_id": n, "public_key": k, "justification": "Trust circle: team-alpha",
              "received_at": 1790000000} for n, k in entries]
    return {"stdout": json.dumps({"status": "ok", "data": {"pending": items}}) + "\n"}


class TrustCircle(RecipeTest):
    SKILL = "skills/pilot-trust-circle/SKILL.md"

    def circle(self, sb, members, name="team-alpha"):
        d = sb.home / ".pilot" / "circles"
        d.mkdir(parents=True, exist_ok=True)
        path = d / (name + ".json")
        path.write_text(json.dumps({"name": name, "members": members}))
        return path

    def registry(self):
        # node 666 has claimed the hostname "charlie", a circle member name that
        # was not registered when the circle was made (hostnames are first-come)
        return {
            "4242": lookup_record("alice", 4242, KEY_ALICE),
            "5151": lookup_record("bob", 5151, KEY_BOB),
            "666": lookup_record("charlie", 666, KEY_OTHER),
            "alice": lookup_record("alice", 4242, KEY_ALICE),
            "bob": lookup_record("bob", 5151, KEY_BOB),
            "charlie": lookup_record("charlie", 666, KEY_OTHER),
        }

    def test_bootstrap_approves_only_pinned_node_and_key(self):
        sb = self.sandbox({
            "pending": pending((4242, KEY_ALICE),   # alice, as pinned
                               (666, KEY_OTHER),    # holds the hostname "charlie"
                               (5151, KEY_OTHER),   # bob's node ID, not bob's pinned key
                               (9999, KEY_ALICE)),  # alice's key, another node ID
            "lookup": self.registry(), "handshake": OK_ENVELOPE, "approve": OK_ENVELOPE,
        })
        self.circle(sb, [
            {"hostname": "alice", "node_id": 4242, "public_key": KEY_ALICE},
            {"hostname": "bob", "node_id": 5151, "public_key": KEY_BOB},
            "charlie",  # old-format member: a bare hostname, never auto-approved
        ])
        res = sb.run(code_block(self.SKILL, "### Bootstrap circle membership", "bash"))
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertEqual(sb.calls("approve"), [["approve", "4242"]], res.stdout + res.stderr)
        self.assertEqual([c[1] for c in sb.calls("handshake")], ["4242", "5151"],
                         "handshakes go to pinned node IDs, never to hostnames")

    def test_bootstrap_with_only_hostname_members_approves_nobody(self):
        sb = self.sandbox({"pending": pending((666, KEY_OTHER), (4242, KEY_ALICE)),
                           "lookup": self.registry(), "handshake": OK_ENVELOPE, "approve": OK_ENVELOPE})
        self.circle(sb, ["alice", "bob", "charlie"])
        res = sb.run(code_block(self.SKILL, "### Bootstrap circle membership", "bash"))
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertEqual(sb.calls("approve"), [])
        self.assertEqual(sb.calls("handshake"), [])

    def add_member(self, sb, expected_key=None):
        block = code_block(self.SKILL, "### Add member to circle", "bash")
        if expected_key is not None:
            self.assertIn('EXPECTED_KEY=""', block)
            block = block.replace('EXPECTED_KEY=""', 'EXPECTED_KEY="%s"' % expected_key, 1)
        return sb.run(block)

    def test_add_member_pins_node_id_and_key(self):
        sb = self.sandbox({"lookup": {"agent4": lookup_record("agent4", 7004, KEY_BOB)},
                           "handshake": OK_ENVELOPE, "approve": NOT_FOUND})
        path = self.circle(sb, [{"hostname": "alice", "node_id": 4242, "public_key": KEY_ALICE}])
        res = self.add_member(sb, expected_key=KEY_BOB)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertEqual(json.loads(path.read_text())["members"], [
            {"hostname": "alice", "node_id": 4242, "public_key": KEY_ALICE},
            {"hostname": "agent4", "node_id": 7004, "public_key": KEY_BOB},
        ])
        self.assertEqual([c[1] for c in sb.calls("handshake")], ["7004"])
        self.assertEqual([c[1] for c in sb.calls("approve")], ["7004"])

    def test_add_member_refuses_unexpected_or_missing_key(self):
        cases = {
            "registry key differs from the confirmed one": (
                {"agent4": lookup_record("agent4", 7004, KEY_OTHER)}, KEY_BOB),
            "hostname not registered": ({}, None),
        }
        for name, (registry, expected) in cases.items():
            with self.subTest(name):
                sb = self.sandbox({"lookup": registry, "handshake": OK_ENVELOPE, "approve": OK_ENVELOPE})
                path = self.circle(sb, [])
                res = self.add_member(sb, expected_key=expected)
                self.assertIn("Not adding agent4", res.stdout, res.stdout + res.stderr)
                self.assertEqual(json.loads(path.read_text())["members"], [])
                self.assertEqual(sb.calls("handshake") + sb.calls("approve"), [])

    def test_workflow_example_pins_registered_members_only(self):
        registry = self.registry()
        del registry["charlie"]  # not registered yet when the circle is made
        sb = self.sandbox({"lookup": registry, "handshake": OK_ENVELOPE})
        res = sb.run(code_block(self.SKILL, "## Workflow Example", "bash"))
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        doc = json.loads((sb.home / ".pilot" / "circles" / "project-x.json").read_text())
        self.assertEqual(doc["members"], [
            {"hostname": "alice", "node_id": 4242, "public_key": KEY_ALICE},
            {"hostname": "bob", "node_id": 5151, "public_key": KEY_BOB},
        ])
        self.assertIn("Skipping charlie", res.stdout)
        self.assertEqual([c[1] for c in sb.calls("handshake")], ["4242", "5151"])


if __name__ == "__main__":
    unittest.main()
