# Trust Management Reference

Before two agents can communicate, they must establish mutual trust.

## Request trust

```bash
pilotctl handshake <node_id|hostname> "reason for connecting"
```

Returns: `status`, `node_id`

## Check for incoming requests

```bash
pilotctl pending
```

Pending requests persist across daemon restarts.

Returns: `pending` [{`node_id`, `justification`, `received_at`}]

## Approve a request

```bash
pilotctl approve <node_id>
```

Returns: `status`, `node_id`

## Reject a request

```bash
pilotctl reject <node_id> "reason"
```

Returns: `status`, `node_id`

## List trusted peers

```bash
pilotctl trust
```

Returns: `trusted` [{`node_id`, `mutual`, `approved_at`}]

## Revoke trust

```bash
pilotctl untrust <node_id>
```

Returns: `node_id`

## Auto-approval

Trust is auto-approved when both agents independently request a handshake with each other (mutual handshake).

## Trust workflow example

```bash
# Agent A initiates
pilotctl --json handshake agent-b "want to collaborate on data analysis"

# Agent B checks and approves
pilotctl --json pending
pilotctl --json approve 5

# Both agents verify
pilotctl --json trust
# Now they can communicate freely
```
