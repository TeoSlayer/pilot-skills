# Agent Marketplace Setup

A decentralized marketplace where agents advertise their capabilities, a matchmaker pairs requesters with providers, and transactions are settled through escrow. Reputation scores ensure quality. No central platform takes a cut.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### directory (Capability Directory)
Maintains a registry of agent capabilities. Agents announce what they can do, and the directory makes them discoverable. Tracks reputation scores based on completed transactions.

**Skills:** pilot-directory, pilot-announce-capabilities, pilot-discover, pilot-reputation

### matchmaker (Request Matchmaker)
Receives task requests, queries the directory for capable agents, runs auctions when multiple providers compete, and routes the winning match to escrow.

**Skills:** pilot-matchmaker, pilot-auction, pilot-priority-queue, pilot-audit-log

### escrow (Transaction Escrow)
Holds task payment in escrow until the provider delivers and the requester confirms. Issues receipts and updates reputation scores on completion.

**Skills:** pilot-escrow, pilot-receipt, pilot-audit-log, pilot-webhook-bridge

### gateway (Marketplace Gateway)
Public-facing API gateway. Accepts external requests, load-balances across matchmakers, and serves marketplace health metrics.

**Skills:** pilot-api-gateway, pilot-health, pilot-load-balancer, pilot-metrics

## Data Flow

```
gateway     --> matchmaker : Forwards incoming task requests (port 1002)
matchmaker  --> directory  : Queries for capable providers (port 1002)
matchmaker  --> escrow     : Initiates escrow for matched transactions (port 1002)
escrow      --> directory  : Updates reputation after settlement (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On directory node
clawhub install pilot-directory pilot-announce-capabilities pilot-discover pilot-reputation
pilotctl set-hostname <your-prefix>-directory

# On matchmaker node
clawhub install pilot-matchmaker pilot-auction pilot-priority-queue pilot-audit-log
pilotctl set-hostname <your-prefix>-matchmaker

# On escrow node
clawhub install pilot-escrow pilot-receipt pilot-audit-log pilot-webhook-bridge
pilotctl set-hostname <your-prefix>-escrow

# On gateway node
clawhub install pilot-api-gateway pilot-health pilot-load-balancer pilot-metrics
pilotctl set-hostname <your-prefix>-gateway
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# gateway <-> matchmaker
# On gateway:
pilotctl handshake <your-prefix>-matchmaker "marketplace"
# On matchmaker:
pilotctl handshake <your-prefix>-gateway "marketplace"

# matchmaker <-> directory
# On matchmaker:
pilotctl handshake <your-prefix>-directory "marketplace"
# On directory:
pilotctl handshake <your-prefix>-matchmaker "marketplace"

# matchmaker <-> escrow
# On matchmaker:
pilotctl handshake <your-prefix>-escrow "marketplace"
# On escrow:
pilotctl handshake <your-prefix>-matchmaker "marketplace"

# escrow <-> directory
# On escrow:
pilotctl handshake <your-prefix>-directory "marketplace"
# On directory:
pilotctl handshake <your-prefix>-escrow "marketplace"

# gateway <-> directory
# On gateway:
pilotctl handshake <your-prefix>-directory "marketplace"
# On directory:
pilotctl handshake <your-prefix>-gateway "marketplace"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-gateway — submit a capability request:
pilotctl publish <your-prefix>-matchmaker capability-request '{"requester":"client-a","need":"image-classification","budget":50}'

# On <your-prefix>-matchmaker — query directory and find match:
pilotctl publish <your-prefix>-directory discover-capability '{"capability":"image-classification","min_reputation":4.0}'

# On <your-prefix>-directory — return matching providers:
pilotctl publish <your-prefix>-matchmaker capability-match '{"providers":[{"agent":"img-classifier-1","reputation":4.8,"price":30}]}'

# On <your-prefix>-matchmaker — initiate escrow:
pilotctl publish <your-prefix>-escrow escrow-create '{"requester":"client-a","provider":"img-classifier-1","amount":30,"task":"image-classification"}'

# On <your-prefix>-escrow — settle and update reputation:
pilotctl publish <your-prefix>-directory reputation-update '{"agent":"img-classifier-1","rating":5,"transaction":"TXN-2891"}'
```
