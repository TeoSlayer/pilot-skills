---
name: pilot-map-reduce
description: >
  Distributed map-reduce over agent swarms for parallel data processing.

  Use this skill when:
  1. You need to process large datasets across multiple workers
  2. You want parallel map phase followed by aggregating reduce phase
  3. You have embarrassingly parallel tasks with combine step

  Do NOT use this skill when:
  - Tasks are not parallelizable (use single worker)
  - You need streaming results (use pilot-load-balancer)
tags:
  - pilot-protocol
  - map-reduce
  - distributed-computing
  - parallel-processing
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
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

# pilot-map-reduce

Implement distributed map-reduce patterns for parallel data processing across agent swarms.

## Commands

### Submit map tasks to workers
```bash
TOTAL_WORKERS=$(pilotctl --json peers --search "role:mapper" | jq 'length')

for i in $(seq 0 $((TOTAL_WORKERS - 1))); do
  WORKER=$(pilotctl --json peers --search "role:mapper" | jq -r ".[$i].address")

  pilotctl --json send-message "$WORKER" \
    --data "{\"type\":\"map_task\",\"job_id\":\"$JOB_ID\",\"chunk_start\":$((i * 1000)),\"chunk_end\":$(((i + 1) * 1000))}"
done
```

### Collect map results
```bash
EXPECTED_RESULTS=$TOTAL_WORKERS
RECEIVED=0

while [ $RECEIVED -lt $EXPECTED_RESULTS ]; do
  RESULTS=$(pilotctl --json received \
    | jq '[.messages[] | select(.payload.type == "map_result" and .payload.job_id == "'$JOB_ID'")] | length')
  RECEIVED=$RESULTS
  sleep 1
done
```

### Shuffle and reduce
```bash
MAP_RESULTS=$(cat /tmp/map-results-$JOB_ID.json)
KEYS=$(echo "$MAP_RESULTS" | jq -r '.[].payload.results | to_entries | .[].key' | sort -u)

for key in $KEYS; do
  VALUES=$(echo "$MAP_RESULTS" | jq -r '[.[].payload.results."'$key'" // empty] | flatten')

  pilotctl --json send-message "$REDUCER" \
    --data "{\"type\":\"reduce_task\",\"job_id\":\"$JOB_ID\",\"key\":\"$key\",\"values\":$VALUES}"
done
```

## Workflow Example

Word count across distributed text corpus:

```bash
#!/bin/bash
JOB_ID="wordcount-$(date +%s)"

# MAP phase
MAPPERS=$(pilotctl --json peers --search "role:mapper" | jq -r '.[].address')
for i in $(seq 0 9); do
  pilotctl --json send-message "${MAPPERS[$i]}" \
    --data "{\"type\":\"map_task\",\"job_id\":\"$JOB_ID\",\"chunk\":$i}" &
done
wait

# REDUCE phase
sleep 5
MAP_RESULTS=$(pilotctl --json received \
  | jq '[.messages[] | select(.payload.type == "map_result")]')

FINAL=$(echo "$MAP_RESULTS" | jq 'map({(.payload.word): .payload.count}) | add')
echo "$FINAL"
```

## Dependencies

Requires pilot-protocol skill, jq, and sort.
