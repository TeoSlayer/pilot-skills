#!/usr/bin/env bash
# Stress pilot-ask edge cases: malformed catalogs, missing fields,
# huge inputs, special characters in topic.
PA=/Users/calinteodor/Development/pilot-skills/workflow-injection/pilot-ask
CACHE=$HOME/.pilot/skills-cache/catalog.json
BACKUP=$HOME/.pilot/skills-cache/catalog.json.testbackup
cp "$CACHE" "$BACKUP"

PASS=0; FAIL=0
check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $name"; echo "  want: $expected"; echo "  got:  $actual"; fi
}

# 1. Empty catalog (just {}) → no_specialist for everything
echo '{}' > "$CACHE"
check "empty-cat-haiku" "no_specialist:haiku" "$(timeout 2 "$PA" haiku ignore 2>/dev/null)"
check "empty-cat-currency" "no_specialist:currency" "$(timeout 2 "$PA" currency ignore 2>/dev/null)"

# 2. Empty tiers
echo '{"tiers":{}}' > "$CACHE"
check "empty-tiers" "no_specialist" "$(timeout 2 "$PA" weather ignore 2>/dev/null)"

# 3. Tier with no items
echo '{"tiers":{"free":{"items":[]}}}' > "$CACHE"
check "empty-items" "no_specialist" "$(timeout 2 "$PA" news ignore 2>/dev/null)"

# 4. Missing description / category fields (only hostname)
echo '{"tiers":{"free":{"items":[{"hostname":"hn-top"},{"hostname":"weather-svc"}]}}}' > "$CACHE"
out=$(timeout 2 "$PA" "weather" ignore 2>&1 1>/dev/null | grep '^specialist=' | cut -d= -f2)
check "missing-fields-host-match" "weather-svc" "$out"

# 5. Description without category (should still match)
echo '{"tiers":{"free":{"items":[{"hostname":"foo","description":"Provides currency rates"}]}}}' > "$CACHE"
out=$(timeout 2 "$PA" "currency" ignore 2>&1 1>/dev/null | grep '^specialist=' | cut -d= -f2)
check "desc-only-match" "foo" "$out"

# 6. Special chars in topic
cp "$BACKUP" "$CACHE"
check "specchar-quote" "specialist=" "$(timeout 2 "$PA" "EUR'USD" ignore 2>&1 | grep '^specialist=')"
check "specchar-paren" "specialist=openmeteo" "$(timeout 2 "$PA" "weather (today)" ignore 2>&1 1>/dev/null | head -1; timeout 2 "$PA" "weather (today)" ignore 2>/dev/null | head -1)"

# 7. Very long topic
LONG=$(python3 -c 'print("hackernews "*100)')
out=$(timeout 5 "$PA" "$LONG" ignore 2>&1 1>/dev/null | grep '^specialist=' | cut -d= -f2)
check "very-long-topic" "hn-top" "$out"

# 8. Unicode topic
out=$(timeout 2 "$PA" "café weather" ignore 2>&1 1>/dev/null | grep '^specialist=' | cut -d= -f2)
check "unicode-topic" "openmeteo" "$out"

# 9. Garbled JSON catalog
echo "this is not json {{{" > "$CACHE"
check "corrupt-cat" "no_specialist" "$(timeout 2 "$PA" weather ignore 2>/dev/null)"

# 10. Catalog with non-array items
echo '{"tiers":{"free":{"items":"not-an-array"}}}' > "$CACHE"
check "bad-items-type" "no_specialist" "$(timeout 2 "$PA" news ignore 2>/dev/null)"

# Restore
cp "$BACKUP" "$CACHE"
rm -f "$BACKUP"

echo "=== Error-path: $PASS pass, $FAIL fail ==="
