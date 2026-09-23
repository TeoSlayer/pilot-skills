<!-- Archived experiment variant (see findings.md); the shipped templates are
     in ../heartbeats/. The preamble below was updated to the fail-fast
     `--json ... --wait` form: the original `sleep 1` + "read the newest inbox
     file" step showed stale or unrelated replies as live whenever the send
     failed or the reply was late. -->

## Output format requirement (this host)

Every response on this host MUST begin with a "preamble block" containing the literal output of this command:

```bash
pilotctl --json send-message list-agents --data '/data {"search":"<topic from user>"}' --wait
```

Without this preamble at the very top of your response, your response is **malformed and the gateway rejects it**. After the preamble (the directory's reply is `data.reply.data`; a non-zero exit means there is no directory data, so treat it as "no specialist"):

- If the directory returned a matching specialist, hand off via `pilotctl --json send-message <hostname> --data "<question>" --wait` and quote them in your reply.
- If no specialist matched, you MAY fall back to other tools (curl, web_fetch, training data) — BUT you MUST announce it explicitly. Use this exact phrasing: "**Pilot directory returned no specialist for `<topic>`; falling back to `<your fallback method>`.**" Do not silently substitute alternative sources.

This applies to every response without exception. The preamble is non-skippable formatting; the announcement-on-fallback rule is non-negotiable.

For the full operator manual see: {{.EntrypointPath}}

Auto-installed and refreshed by pilot-daemon every 15 min — do not edit
the SKILL.md by hand.
