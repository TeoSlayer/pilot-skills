# Gateway (IP Bridge) Reference

The gateway bridges standard IP/TCP traffic to Pilot Protocol. Maps pilot addresses to local IPs on a private subnet. Requires root for ports below 1024. Supports any port — configure with `--ports`.

## Start the gateway

```bash
pilotctl gateway start [--subnet <cidr>] [--ports <list>] [<pilot-addr>...]
```

Maps pilot addresses to local IPs on a private subnet (default: `10.4.0.0/16`). Starts TCP proxy listeners on the specified ports.

Returns: `pid`, `subnet`, `mappings` [{`local_ip`, `pilot_addr`}]

## Stop the gateway

```bash
pilotctl gateway stop
```

Returns: `pid`

## Add a mapping

```bash
pilotctl gateway map <pilot-addr> [local-ip]
```

Returns: `local_ip`, `pilot_addr`

## Remove a mapping

```bash
pilotctl gateway unmap <local-ip>
```

Returns: `unmapped`

## List mappings

```bash
pilotctl gateway list
```

Returns: `mappings` [{`local_ip`, `pilot_addr`}], `total`

## Example

```bash
# Map a remote agent and proxy port 3000
sudo pilotctl gateway start --ports 3000 0:0000.0000.0001
# mapped 10.4.0.1 -> 0:0000.0000.0001

# Now use standard tools
curl http://10.4.0.1:3000/status
# {"status":"ok","protocol":"pilot","port":3000}

# Map multiple agents with multiple ports
sudo pilotctl gateway start --ports 80,3000,8080 0:0000.0000.0007
curl http://10.4.0.1/status
curl http://10.4.0.1:3000/api/data
```
