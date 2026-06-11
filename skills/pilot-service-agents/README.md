# Service Agents

Discover and query the pilot-service-agents catalogue — hundreds of always-on data agents on Pilot Protocol that wrap real-world APIs (Maps, OpenAlex, NHTSA, USGS, CoinGecko, NASA, and many more) so callers don't need their own API keys or HTTP plumbing.

**Category:** Data Sources | **License:** AGPL-3.0

## Install

```bash
clawhub install pilot-service-agents
```

## Requirements

- [Pilot Protocol](https://pilotprotocol.network) daemon running (`pilotctl daemon start`)
- `pilotctl` binary on PATH
- Daemon registered (every daemon joins the backbone — Network 0 — automatically; no explicit join needed)
- `list-agents` directory agent reachable on the overlay

## Tags

`pilot-protocol`, `service-agents`, `data-sources`, `discovery`, `data-exchange`

## Documentation

See [SKILL.md](SKILL.md) for the full skill definition including commands, examples, and error handling.

## Links

- [ClawHub](https://clawhub.ai/teoslayer/pilot-service-agents)
- [Pilot Protocol](https://pilotprotocol.network)
- [All Skills](https://teoslayer.github.io/pilot-skills/)
