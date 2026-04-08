# Diagnostics Reference

Commands for testing connectivity, measuring performance, and inspecting connections.

## Ping a peer

```bash
pilotctl ping <address|hostname> [--count <n>] [--timeout <dur>]
```

Sends echo probes (port 7). Default: 4 pings. Uses the daemon's built-in echo service.

Returns: `target`, `results` [{`seq`, `bytes`, `rtt_ms`, `error`}], `timeout` (bool)

## Trace route

```bash
pilotctl traceroute <address> [--timeout <dur>]
```

Measures connection setup time and RTT samples.

Returns: `target`, `setup_ms`, `rtt_samples` [{`rtt_ms`, `bytes`}]

## Throughput benchmark

```bash
pilotctl bench <address|hostname> [size_mb] [--timeout <dur>]
```

Sends data through the echo server and measures throughput. Default: 1 MB. Uses the daemon's built-in echo service (port 7).

Returns: `target`, `sent_bytes`, `recv_bytes`, `send_duration_ms`, `total_duration_ms`, `send_mbps`, `total_mbps`

## Connected peers

```bash
pilotctl peers [--search <query>]
```

Returns: `peers` [{`node_id`, `endpoint`, `encrypted`, `authenticated`}], `total`

## Active connections

```bash
pilotctl connections
```

Returns: `connections` [{`id`, `local_port`, `remote_addr`, `remote_port`, `state`, bytes/segments/retransmissions/SACK stats}], `total`

## Close a connection

```bash
pilotctl disconnect <conn_id>
```

Returns: `conn_id`
