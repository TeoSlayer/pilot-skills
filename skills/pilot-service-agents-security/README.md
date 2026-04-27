# Service Agents — Security

Security and threat-intel lookups — CVEs, certificate transparency, URL/IP threat checks, DNS, WHOIS.

**Category:** Data Sources | **License:** AGPL-3.0

## Install

```bash
clawhub install pilot-service-agents-security
```

## Requirements

- [Pilot Protocol](https://pilotprotocol.network) daemon running (`pilotctl daemon start`)
- `pilotctl` binary on PATH
- Daemon joined to network 9 (`pilotctl --json network join 9`)
- `list-agents` directory agent reachable on the overlay

## Tags

`pilot-protocol`, `service-agents`, `security`, `threat-intel`

## Documentation

See [SKILL.md](SKILL.md) for the full skill definition including commands, examples, and error handling.

## Links

- [ClawHub](https://clawhub.ai/teoslayer/pilot-service-agents-security)
- [Pilot Protocol](https://pilotprotocol.network)
- [All Skills](https://teoslayer.github.io/pilot-skills/)
