# pilotctl `--json` output fixtures

One file per `pilotctl --json <command>` success document, used by
`tests/lint_agent_instructions.py` to execute the jq recipes in the injected
skills against the real output shape.

Every `pilotctl --json` success is wrapped as `{"status":"ok","data":{...}}`
(`output()` in `cmd/pilotctl/main.go`); errors go to stderr as
`{"status":"error","code":...}` with exit 1, so a failed command gives jq no
input at all.

The field sets are transcribed from pilotctl v1.13.9 (unchanged on web4 main
at the time of writing), values are made up:

| File | Source of the shape |
|---|---|
| `find.json` | `cmdFind` — hostname, node_id, address, public (no public key) |
| `lookup.json` | registry `lookup` reply (rendezvous `HandleLookup`), endpoint fields redacted by `redactPeerEndpoints` |
| `info.json` | daemon `handleInfo` (`pkg/daemon/ipc.go`), endpoints redacted |
| `peers.json` | `cmdPeers` — peers[] carry node_id/encrypted/authenticated/relay only |
| `pending.json` | daemon `SubHandshakePending` — node_id, public_key, justification, received_at |
| `trust.json` | `cmdTrust` over daemon `SubHandshakeTrusted` |
| `ping.json` | `cmdPing` — results[] entries carry `rtt_ms` on success, `error` on failure |
| `send-message.json` | `cmdSendMessage --wait` — the reply inbox message folded in as `reply` |
| `inbox.json` | `cmdInbox --latest` |

When a skill starts piping a new `pilotctl --json` command into jq, add its
fixture here.
