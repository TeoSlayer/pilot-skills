# Communication Reference

Detailed documentation for all Pilot Protocol communication commands.

## Send a message and get a response

```bash
pilotctl connect <address|hostname> [port] --message "<msg>" [--timeout <dur>]
```

Non-interactive. Dials the target, sends the message, reads one response, exits. Default port: 1000 (stdio).

Returns: `target`, `port`, `sent`, `response`

## Send data to a specific port

```bash
pilotctl send <address|hostname> <port> --data "<msg>" [--timeout <dur>]
```

Opens a connection to the specified port, sends the data, reads one response, exits.

Returns: `target`, `port`, `sent`, `response`

## Receive incoming messages

```bash
pilotctl recv <port> [--count <n>] [--timeout <dur>]
```

Listens on a port, accepts incoming connections, and collects messages. Default count: 1.

Returns: `messages` [{`seq`, `port`, `data`, `bytes`}], `timeout` (bool)

## Pipe mode (stdin)

```bash
echo "hello" | pilotctl connect <address|hostname> [port] [--timeout <dur>]
```

Without `--message`: reads data from stdin (piped), sends it, reads one response. Requires piped input — not interactive.

## Send a file

```bash
pilotctl send-file <address|hostname> <filepath>
```

Sends a file via the data exchange protocol (port 1001). The target's daemon saves it to `~/.pilot/received/` and ACKs. List received files with `pilotctl received`.

Returns: `filename`, `bytes`, `destination`, `ack`

## Send a typed message

```bash
pilotctl send-message <address|hostname> --data "<text>" [--type text|json|binary]
```

Sends a typed message via data exchange (port 1001). Default type: `text`. The target saves the message to its inbox (`~/.pilot/inbox/`).

Returns: `target`, `type`, `bytes`, `ack`

## Subscribe to events

```bash
pilotctl subscribe <address|hostname> <topic> [--count <n>] [--timeout <dur>]
```

Subscribes to a topic on the target's event stream broker (port 1002). Use `*` to receive all topics. Without `--count`: streams NDJSON (one JSON object per line). With `--count`: collects N events and returns a JSON array.

Returns: `events` [{`topic`, `data`, `bytes`}], `timeout` (bool). Unbounded: NDJSON per line.

## Publish an event

```bash
pilotctl publish <address|hostname> <topic> --data "<message>"
```

Publishes an event to the target's event stream broker (port 1002). The event is distributed to all subscribers of the topic.

Returns: `target`, `topic`, `bytes`

## Listen for datagrams

```bash
pilotctl listen <port> [--count <n>] [--timeout <dur>]
```

Listens for incoming datagrams. Without `--count`: streams NDJSON indefinitely (one JSON object per line). With `--count`/`--timeout`: collects bounded results.

Returns: `messages` [{`src_addr`, `src_port`, `data`, `bytes`}], `timeout` (bool)

## Broadcast

```bash
pilotctl broadcast <network_id> <message>
```

**Not yet available.** Broadcast requires custom networks, which are currently in development.

Returns: `network_id`, `message`
