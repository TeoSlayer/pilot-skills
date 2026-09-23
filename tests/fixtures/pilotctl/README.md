# pilotctl `--json` output fixtures

Each file holds what `pilotctl --json <command>` prints on **stdout**, one
JSON document per line, exactly as a `| jq` pipeline receives it. They are
used by `tests/lint_agent_instructions.py` to execute the jq recipes in the
injected skills against the real output shape, and by
`tests/test_skill_recipes.py` as the output of a stub `pilotctl`.

Every `pilotctl --json` document is wrapped as `{"status":"ok","data":{...}}`
(`output()` in `cmd/pilotctl/main.go`). Most errors go to stderr as
`{"status":"error","code":...}` with exit 1 and nothing on stdout, so jq
gets no input at all. **Not every failure looks like that**, which is why
the `fail-*` files exist:

- `ping` always prints its results document on stdout, then exits 1 when
  every probe failed. Each probe starts as `{"seq","rtt_ms"}` once the dial
  succeeds, and gets an `error` if the echo read then fails, so a failed
  probe can carry both `rtt_ms` and `error`. Only a successful probe has
  `bytes` and no `error`. With `--count > 1`, the overall `--timeout` (default
  5 s) can fire while the per-probe floor (10 s) is still running. ping then
  prints `"timeout": true` with only failed probes and exits **0**.
- `send-message --wait` in pilotctl v1.12.2 and older (before web4 3a71dbb3,
  first released in v1.12.3) prints **two** documents: the send result, then
  the reply message itself, whose body is `.data.data`. It has no
  `data.reply`. When no reply arrives it prints the send result, then exits
  1. skillinject on those nodes still fetches this repo's text, so recipes
  must work on both shapes: `.data.reply.data // .data.data // empty`.

## Files

`<cmd>.json` is the current success output (pilotctl v1.13.9, unchanged on
web4 main at the time of writing; values are made up). `<cmd>.ok-<label>.json`
is another successful output a recipe must also handle.
`<cmd>.fail-<label>.json` is what a **failed** `<cmd>` still prints on stdout.
A `jq -e` recipe must be false on it. The lint also runs every `jq -e` recipe
on empty input.

| File | Source of the shape |
|---|---|
| `find.json` | `cmdFind`: hostname, node_id, address, public (no public key) |
| `lookup.json` | registry `lookup` reply (rendezvous `HandleLookup`), endpoint fields redacted by `redactPeerEndpoints` |
| `info.json` | daemon `handleInfo` (`pkg/daemon/ipc.go`), endpoints redacted |
| `peers.json` | `cmdPeers`: peers[] carry node_id/encrypted/authenticated/relay only |
| `pending.json` | daemon `SubHandshakePending`: node_id, public_key (base64 Ed25519, the same encoding as `lookup`), justification, received_at |
| `trust.json` | `cmdTrust` over daemon `SubHandshakeTrusted` |
| `ping.json` | `cmdPing`, one successful probe: `seq`, `rtt_ms`, `bytes`, no `error` |
| `ping.fail-echo-timeout.json` | `cmdPing`: dial succeeded, echo read timed out. The probe has `rtt_ms` **and** `error`; pilotctl exits 1 |
| `ping.fail-dial.json` | `cmdPing`: dial failed. The probe has `seq` and `error` only; pilotctl exits 1 |
| `ping.fail-overall-timeout.json` | `cmdPing --count 4`: the overall timer fired after the first probe lost its echo. That probe has `rtt_ms` and `error`, the document has `"timeout": true`, and pilotctl exits **0** |
| `send-message.json` | `cmdSendMessage --wait`, v1.12.3+: the reply inbox message folded in as `reply` |
| `send-message.ok-v1.12.2.json` | `cmdSendMessage --wait`, v1.12.2 and older: send result, then the reply message (`.data.data`) as a second document |
| `send-message.fail-v1.12.2-timeout.json` | `cmdSendMessage --wait`, v1.12.2 and older, no reply: the send result only; pilotctl exits 1 |
| `inbox.json` | `cmdInbox --latest` |

When a skill starts piping a new `pilotctl --json` command into jq, add its
fixture here. If that command can fail while still printing JSON on stdout,
add a `fail-*` file too.
