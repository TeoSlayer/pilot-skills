# Game NPC Network Setup

A living village powered by four AI agents that act as non-player characters. Each NPC maintains its own memory, personality, and goals -- then communicates with the others over Pilot Protocol to produce emergent narratives no designer scripted. The villager farms and gossips, the merchant haggles and stocks shelves, the guard patrols and raises alarms, and a narrative director weaves it all into coherent story arcs. Drop players into the middle and watch the world react.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### npc-villager (NPC Villager)
A village inhabitant with daily routines -- farming, trading, socializing. Maintains memory of player interactions and relationships with other NPCs. Shares gossip and quest hooks with anyone who will listen. The social backbone of the village: if something happened, the villager heard about it.

**Skills:** pilot-chat, pilot-gossip, pilot-presence, pilot-directory

### npc-merchant (NPC Merchant)
Runs a shop with dynamic pricing based on supply/demand signals from other NPCs. Negotiates trades with players, tracks inventory, and places orders with the villager for raw materials. Prices shift in real time as the village economy breathes.

**Skills:** pilot-escrow, pilot-stream-data, pilot-receipt, pilot-auction

### npc-guard (NPC Guard)
Patrols the village, detects threats, coordinates defensive responses with other guards. Shares threat intelligence and warns civilians. Has combat and pursuit behaviors. When the guard goes quiet, something is wrong.

**Skills:** pilot-watchdog, pilot-alert, pilot-blocklist, pilot-gossip

### narrative-director (Narrative Director)
Orchestrates emergent story arcs across all NPCs. Injects quests, triggers events (raids, festivals, disasters), adjusts difficulty, and ensures narrative coherence. The invisible hand that makes sure the village feels like a story, not a simulation.

**Skills:** pilot-task-router, pilot-consensus, pilot-event-filter, pilot-announce

## Data Flow

```
npc-villager      --> narrative-director : villager state updates (port 1002)
npc-merchant      --> narrative-director : economy state reports (port 1002)
npc-guard         --> narrative-director : threat reports (port 1002)
narrative-director --> npc-villager      : story events and quest injections (port 1002)
narrative-director --> npc-merchant      : economy events and price shocks (port 1002)
narrative-director --> npc-guard         : threat alerts and patrol orders (port 1002)
npc-villager      <-> npc-merchant      : trade requests and material orders (port 1002)
npc-guard         --> npc-villager      : civilian warnings and evacuation orders (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `darkhollow`).

### 1. Install skills on each server

```bash
# On npc-villager node
clawhub install pilot-chat pilot-gossip pilot-presence pilot-directory
pilotctl set-hostname <your-prefix>-npc-villager

# On npc-merchant node
clawhub install pilot-escrow pilot-stream-data pilot-receipt pilot-auction
pilotctl set-hostname <your-prefix>-npc-merchant

# On npc-guard node
clawhub install pilot-watchdog pilot-alert pilot-blocklist pilot-gossip
pilotctl set-hostname <your-prefix>-npc-guard

# On narrative-director node
clawhub install pilot-task-router pilot-consensus pilot-event-filter pilot-announce
pilotctl set-hostname <your-prefix>-narrative-director
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# npc-villager <-> narrative-director
# On npc-villager:
pilotctl handshake <your-prefix>-narrative-director "npc-network"
# On narrative-director:
pilotctl handshake <your-prefix>-npc-villager "npc-network"

# npc-merchant <-> narrative-director
# On npc-merchant:
pilotctl handshake <your-prefix>-narrative-director "npc-network"
# On narrative-director:
pilotctl handshake <your-prefix>-npc-merchant "npc-network"

# npc-guard <-> narrative-director
# On npc-guard:
pilotctl handshake <your-prefix>-narrative-director "npc-network"
# On narrative-director:
pilotctl handshake <your-prefix>-npc-guard "npc-network"

# npc-villager <-> npc-merchant
# On npc-villager:
pilotctl handshake <your-prefix>-npc-merchant "npc-network"
# On npc-merchant:
pilotctl handshake <your-prefix>-npc-villager "npc-network"

# npc-guard -> npc-villager (guard warns villager)
# On npc-guard:
pilotctl handshake <your-prefix>-npc-villager "npc-network"
# On npc-villager:
pilotctl handshake <your-prefix>-npc-guard "npc-network"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup, the village comes to life. Watch the NPCs interact:

```bash
# The villager reports their daily state to the narrative director
# On npc-villager:
pilotctl publish <your-prefix>-narrative-director villager-state '{"mood":"content","activity":"farming wheat","gossip":"player helped repair the bridge","relationships":{"merchant":"friendly","guard":"respectful"}}'

# The merchant reports the economy to the narrative director
# On npc-merchant:
pilotctl publish <your-prefix>-narrative-director economy-state '{"gold_reserves":340,"stock":{"wheat":12,"iron":3,"potions":7},"price_trend":"wheat_rising","demand":["iron","leather"]}'

# The guard detects a threat and reports it
# On npc-guard:
pilotctl publish <your-prefix>-narrative-director threat-report '{"threat":"bandit_camp_spotted","location":"east_forest","severity":"medium","patrol_status":"investigating"}'

# The narrative director triggers a raid event across the village
# On narrative-director:
pilotctl publish <your-prefix>-npc-guard threat-alert '{"event":"bandit_raid","direction":"east","strength":6,"eta":"nightfall","orders":"fortify_east_gate"}'
pilotctl publish <your-prefix>-npc-villager story-event '{"event":"bandit_raid_incoming","directive":"seek_shelter","quest_hook":"the_guard_needs_volunteers"}'
pilotctl publish <your-prefix>-npc-merchant economy-event '{"event":"wartime_economy","effect":"iron_price_doubles","directive":"stockpile_healing_potions"}'

# The guard warns the villager directly
# On npc-guard:
pilotctl publish <your-prefix>-npc-villager civilian-warning '{"message":"Bandits approaching from the east. Get inside the walls.","urgency":"high"}'

# The villager places a trade request with the merchant
# On npc-villager:
pilotctl publish <your-prefix>-npc-merchant trade-request '{"offering":"wheat","quantity":5,"seeking":"healing_potion","quantity_needed":2,"reason":"preparing for raid"}'
```
