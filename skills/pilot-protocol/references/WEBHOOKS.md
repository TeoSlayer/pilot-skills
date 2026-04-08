# Webhooks Reference

The daemon can POST JSON events to an HTTP endpoint in real time. Configure at startup or at runtime.

## Set webhook at startup

```bash
pilotctl daemon start --webhook http://localhost:8080/events
```

## Set webhook at runtime

```bash
pilotctl set-webhook <url>
```

Persists to `~/.pilot/config.json` and applies immediately to a running daemon.

Returns: `webhook`, `applied` (bool — true if daemon is running)

## Clear webhook

```bash
pilotctl clear-webhook
```

Removes the webhook URL from config and the running daemon.

Returns: `webhook`, `applied` (bool)

## Event Types

| Event | Description |
|-------|-------------|
| `node.registered` | Daemon registered with the registry |
| `node.reregistered` | Re-registration after keepalive timeout |
| `node.deregistered` | Daemon deregistered |
| `conn.syn_received` | Incoming connection request |
| `conn.established` | Connection fully established |
| `conn.fin` | Connection closed gracefully |
| `conn.rst` | Connection reset |
| `conn.idle_timeout` | Connection timed out |
| `tunnel.peer_added` | New tunnel peer discovered |
| `tunnel.established` | Tunnel handshake completed |
| `tunnel.relay_activated` | Relay fallback activated for a peer |
| `handshake.received` | Trust handshake request received |
| `handshake.pending` | Handshake queued for approval |
| `handshake.approved` | Handshake approved |
| `handshake.rejected` | Handshake rejected |
| `handshake.auto_approved` | Mutual handshake auto-approved |
| `trust.revoked` | Trust revoked locally |
| `trust.revoked_by_peer` | Trust revoked by remote peer |
| `message.received` | Typed message received via data exchange |
| `file.received` | File received via data exchange |
| `pubsub.subscribed` | Subscriber joined a topic |
| `pubsub.unsubscribed` | Subscriber left a topic |
| `pubsub.published` | Event published to a topic |
| `data.datagram` | Datagram received |
| `security.syn_rate_limited` | SYN rate limiter triggered |
| `security.nonce_replay` | Nonce replay detected |

## Payload Format

```json
{
  "event": "handshake.received",
  "node_id": 5,
  "timestamp": "2026-01-15T12:34:56Z",
  "data": {
    "peer_node_id": 7,
    "justification": "want to collaborate"
  }
}
```
