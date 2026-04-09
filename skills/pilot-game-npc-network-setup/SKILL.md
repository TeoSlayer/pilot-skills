---
name: pilot-game-npc-network-setup
description: >
  Deploy a living NPC village with 4 agents that communicate autonomously.

  Use this skill when:
  1. User wants to set up a game NPC network with emergent behavior
  2. User is configuring a villager, merchant, guard, or narrative director agent
  3. User asks about NPC-to-NPC communication, dynamic economies, or emergent narratives

  Do NOT use this skill when:
  - User wants a single chatbot NPC (use pilot-chat instead)
  - User wants a simple alert system (use pilot-alert instead)
tags:
  - pilot-protocol
  - setup
  - gaming
  - npc
  - emergent-narrative
license: AGPL-3.0
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
        - clawhub
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Game NPC Network Setup

Deploy 4 agents: npc-villager, npc-merchant, npc-guard, and narrative-director.

## Roles

| Role | Hostname | Skills | Purpose |
|------|----------|--------|---------|
| npc-villager | `<prefix>-npc-villager` | pilot-chat, pilot-gossip, pilot-presence, pilot-directory | Social backbone -- farms, gossips, remembers player interactions |
| npc-merchant | `<prefix>-npc-merchant` | pilot-escrow, pilot-stream-data, pilot-receipt, pilot-auction | Dynamic shop -- supply/demand pricing, inventory, trade negotiation |
| npc-guard | `<prefix>-npc-guard` | pilot-watchdog, pilot-alert, pilot-blocklist, pilot-gossip | Village security -- patrols, threat detection, civilian warnings |
| narrative-director | `<prefix>-narrative-director` | pilot-task-router, pilot-consensus, pilot-event-filter, pilot-announce | Story orchestrator -- quests, events, difficulty, narrative coherence |

## Setup Procedure

**Step 1:** Ask the user which role and prefix (e.g. `darkhollow`).

**Step 2:** Install skills:
```bash
# npc-villager:
clawhub install pilot-chat pilot-gossip pilot-presence pilot-directory
# npc-merchant:
clawhub install pilot-escrow pilot-stream-data pilot-receipt pilot-auction
# npc-guard:
clawhub install pilot-watchdog pilot-alert pilot-blocklist pilot-gossip
# narrative-director:
clawhub install pilot-task-router pilot-consensus pilot-event-filter pilot-announce
```

**Step 3:** Set hostname and write manifest to `~/.pilot/setups/game-npc-network.json`.

**Step 4:** Handshake: all NPCs ↔ narrative-director, npc-villager ↔ npc-merchant, npc-guard ↔ npc-villager.

## Manifest Templates Per Role

### npc-villager
```json
{
  "setup": "game-npc-network", "role": "npc-villager", "role_name": "NPC Villager",
  "hostname": "<prefix>-npc-villager",
  "skills": {
    "pilot-chat": "Converse with players and other NPCs.",
    "pilot-gossip": "Spread and receive rumors across the village.",
    "pilot-presence": "Broadcast location and activity state.",
    "pilot-directory": "Look up other NPCs by role or name."
  },
  "handshakes_needed": ["<prefix>-narrative-director", "<prefix>-npc-merchant", "<prefix>-npc-guard"]
}
```

### npc-merchant
```json
{
  "setup": "game-npc-network", "role": "npc-merchant", "role_name": "NPC Merchant",
  "hostname": "<prefix>-npc-merchant",
  "skills": {
    "pilot-escrow": "Hold trade value until both parties confirm exchange.",
    "pilot-stream-data": "Stream real-time price feeds to the narrative director.",
    "pilot-receipt": "Issue trade receipts for completed transactions.",
    "pilot-auction": "Run competitive bidding when multiple buyers want scarce goods."
  },
  "handshakes_needed": ["<prefix>-narrative-director", "<prefix>-npc-villager"]
}
```

### npc-guard
```json
{
  "setup": "game-npc-network", "role": "npc-guard", "role_name": "NPC Guard",
  "hostname": "<prefix>-npc-guard",
  "skills": {
    "pilot-watchdog": "Monitor village perimeter for threats.",
    "pilot-alert": "Raise alarms and broadcast threat levels.",
    "pilot-blocklist": "Maintain a list of banned or hostile entities.",
    "pilot-gossip": "Share threat intelligence with other guards and NPCs."
  },
  "handshakes_needed": ["<prefix>-narrative-director", "<prefix>-npc-villager"]
}
```

### narrative-director
```json
{
  "setup": "game-npc-network", "role": "narrative-director", "role_name": "Narrative Director",
  "hostname": "<prefix>-narrative-director",
  "skills": {
    "pilot-task-router": "Route quests and objectives to the right NPCs.",
    "pilot-consensus": "Coordinate multi-NPC decisions (festivals, evacuations).",
    "pilot-event-filter": "Filter and prioritize incoming NPC state reports.",
    "pilot-announce": "Broadcast world events to all village NPCs."
  },
  "handshakes_needed": ["<prefix>-npc-villager", "<prefix>-npc-merchant", "<prefix>-npc-guard"]
}
```

## Data Flows

- `npc-villager -> narrative-director` : villager state, mood, gossip (topic: `villager-state`)
- `npc-merchant -> narrative-director` : economy state, stock levels, price trends (topic: `economy-state`)
- `npc-guard -> narrative-director` : threat reports, patrol status (topic: `threat-report`)
- `narrative-director -> npc-villager` : story events, quest injections (topic: `story-event`)
- `narrative-director -> npc-merchant` : economy events, price shocks (topic: `economy-event`)
- `narrative-director -> npc-guard` : threat alerts, patrol orders (topic: `threat-alert`)
- `npc-villager <-> npc-merchant` : trade requests, material orders (topic: `trade-request`)
- `npc-guard -> npc-villager` : civilian warnings, evacuation orders (topic: `civilian-warning`)

All flows use port 1002 (event stream).

## Workflow Example

```bash
# Villager shares daily state:
pilotctl --json publish <prefix>-narrative-director villager-state '{"mood":"worried","activity":"hiding wheat stores","gossip":"strangers seen near east road"}'

# Narrative director triggers a festival to boost morale:
pilotctl --json publish <prefix>-npc-villager story-event '{"event":"harvest_festival","directive":"prepare_feast","quest_hook":"collect_rare_ingredients"}'
pilotctl --json publish <prefix>-npc-merchant economy-event '{"event":"harvest_festival","effect":"food_prices_drop","directive":"stock_ale_and_decorations"}'
pilotctl --json publish <prefix>-npc-guard threat-alert '{"event":"harvest_festival","orders":"increase_night_patrol","note":"large crowds expected"}'

# Guard spots trouble during the festival:
pilotctl --json publish <prefix>-narrative-director threat-report '{"threat":"pickpocket_ring","severity":"low","location":"market_square"}'
pilotctl --json publish <prefix>-npc-villager civilian-warning '{"message":"Watch your coin purses near the market stalls.","urgency":"low"}'

# Merchant adjusts prices after a supply disruption:
pilotctl --json publish <prefix>-narrative-director economy-state '{"iron_stock":0,"price_change":"iron_unavailable","reason":"supply_route_raided"}'

# Villager trades surplus wheat for potions before trouble hits:
pilotctl --json publish <prefix>-npc-merchant trade-request '{"offering":"wheat","quantity":8,"seeking":"healing_potion","quantity_needed":3}'
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, `clawhub` binary, and a running daemon.
