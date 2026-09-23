---
name: pilot-service-agents-security
description: >
  Security and threat-intel lookups — CVEs, certificate transparency, URL/IP threat checks, DNS, WHOIS.

  Use this skill when:
  1. Looking up a CVE (NVD, MITRE CVE, Shodan CVEDB)
  2. Certificate transparency or domain WHOIS / RDAP lookup
  3. URL / IP threat classification (Web Risk premium, Mullvad, ProxyCheck)

  Do NOT use this skill when:
  - Active scanning or exploitation — these are read-only lookups
  - Breach-data *exposure* — HIBP agent returns breach descriptors only
tags:
  - pilot-protocol
  - service-agents
  - security
  - threat-intel
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill, pilotctl binary on PATH, a running daemon
  registered with the backbone (Network 0 — joined automatically at registration), and the `list-agents` directory agent
  reachable on the overlay.
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# pilot-service-agents-security

Security and threat-intel lookups — CVEs, certificate transparency, URL/IP threat checks, DNS, WHOIS.

All agents in this category follow the standard contract described in
`pilot-service-agents`. Send `/help` to any agent to read its exact filter
schema — the table below is a snapshot; the catalogue grows, so always verify
with a fresh `list-agents` query.

## Agents in this category (snapshot)

| Hostname | Description |
|---|---|
| `crtsh` | Certificate transparency log search |
| `cveawg-mitre` | MITRE CVE record |
| `cvedb-shodan` | Shodan CVEDB lookup by CVE id |
| `dns-google` | Google public DNS resolver (A/AAAA/MX/TXT records) |
| `gcp-web-risk` | Google Web Risk URL threat detection |
| `haveibeenpwned-domains` | HIBP latest data-breach record |
| `mullvad-connection` | Connection info: IP, country, ISP, VPN detection |
| `nvd-cves` | NVD CVE search |
| `proxycheck` | Proxy/VPN/abuse IP lookup |
| `rdap-domain` | RDAP domain WHOIS lookup (IETF standard) |
| `rdap-ip` | RDAP IP address registration lookup |
| `shodan-internetdb` | Shodan IP port/vuln/hostname reconnaissance |

## What you can expect

- Multiple CVE feeds for cross-checking
- crt.sh for subdomain discovery via issued certs
- DNS resolution via Google and RDAP WHOIS

## What NOT to expect

- Zero-day early disclosures
- Paid commercial threat-intel feeds — only public data

## Commands (same pattern for every agent in the category)

```bash
# Read an agent's filter contract
pilotctl --json send-message <hostname> --data "/help" --wait

# Fetch structured data
pilotctl --json send-message <hostname> --data '/data {json filters}' --wait

# Natural-language summary (Gemini)
pilotctl --json send-message <hostname> --data '/summary {json filters}' --wait
```

## Response shape

With `--wait`, `send-message` blocks until the agent replies (up to 30 s by default) and prints one JSON document: the ACK fields (`{"ack":"ACK TEXT N bytes", "bytes":N, "target":"<address>", "type":"text"}`) plus `reply`, the agent's message. The agent's normalised envelope is the JSON string in `data.reply.data` (pilotctl v1.12.2 and older print two JSON documents instead: the send result, then the reply, whose `data.data` is the envelope). A non-zero exit means no reply arrived (the error JSON on stderr has a `code` such as `timeout`) — treat that as *no data*, never as a cue to read older messages from the inbox. A reply that lands after the wait can still be picked up by sender and time: `pilotctl --json inbox --from <hostname> --since 5m --latest`. The envelope:

```json
{
  "source": "<hostname>",
  "items":  [...],
  "count":  <int>,
  "total":  <int|null>,
  "page":   <int|null>,
  "next":   <cursor|null>,
  "truncated": <bool>,
  "upstream_url": "<resolved upstream URL>"
}
```

`/help` returns plain text. `/summary` returns a Gemini-generated prose string. Free-text queries also return Gemini prose.

## Workflow Example

```bash
# 1. Fresh discovery — the catalogue grows, never hard-code
pilotctl --json send-message list-agents --data '/data {"category":"security","limit":20}' --wait

# 2. Read the contract of a specific agent
pilotctl --json send-message nvd-cves --data '/help' --wait

# 3. Query it
pilotctl --json send-message nvd-cves --data '/data {"cveId":"CVE-2021-44228"}' --wait
```

## Dependencies

Requires the `pilot-protocol` core skill, the `pilot-service-agents` skill
(for the general discovery flow), `pilotctl` on PATH, and a running daemon
registered with the backbone (Network 0 — joined automatically at registration).
