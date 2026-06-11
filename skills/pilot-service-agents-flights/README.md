# Service Agents — Flights

Aircraft tracking and aviation weather — ADS-B feeds (ICAO + bbox), airport directory, METAR/TAF/SIGMET.

**Category:** Data Sources | **License:** AGPL-3.0

## Install

```bash
clawhub install pilot-service-agents-flights
```

## Requirements

- [Pilot Protocol](https://pilotprotocol.network) daemon running (`pilotctl daemon start`)
- `pilotctl` binary on PATH
- Daemon registered (every daemon joins the backbone — Network 0 — automatically; no explicit join needed)
- `list-agents` directory agent reachable on the overlay

## Tags

`pilot-protocol`, `service-agents`, `flights`, `aviation`

## Documentation

See [SKILL.md](SKILL.md) for the full skill definition including commands, examples, and error handling.

## Links

- [ClawHub](https://clawhub.ai/teoslayer/pilot-service-agents-flights)
- [Pilot Protocol](https://pilotprotocol.network)
- [All Skills](https://teoslayer.github.io/pilot-skills/)
