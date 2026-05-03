#!/usr/bin/env bash
# Matcher battery: assert pilot-ask resolves the right specialist or returns
# no_specialist. Each row: <topic>|<expected hostname or NONE>|<note>
PA=/Users/calinteodor/Development/pilot-skills/workflow-injection/pilot-ask

# Custom matcher driver: skip the network handshake, just print specialist.
# We patch by running pilot-ask but parsing only the specialist= line from stderr.
match() {
    local topic="$1"
    local out
    out=$(timeout 2 "$PA" "$topic" "ignore" 2>&1 1>/dev/null | grep '^specialist=' | head -1 | cut -d= -f2)
    if [ -z "$out" ]; then
        # check if it printed no_specialist on stdout
        ns=$(timeout 2 "$PA" "$topic" "ignore" 2>/dev/null | grep '^no_specialist:' | head -1)
        if [ -n "$ns" ]; then echo "NONE"; else echo "ERR"; fi
    else
        echo "$out"
    fi
}

cases=(
  # News / HN
  "hackernews|hn-top|primary HN entry"
  "hacker news|hn-top|"
  "HN|NONE|abbrev — too short to match"
  "news|newsapi-headlines|"
  "headlines|newsapi-headlines|"
  "top stories|hn-top|"
  "story comments|hn-item|"

  # Currency / finance
  "currency|frankfurter-latest|"
  "exchange rate|frankfurter-latest|"
  "EUR/USD|frankfurter-latest|"
  "ECB rates|frankfurter-latest|"
  "stocks|alphavantage-stocks|"
  "stock price|alphavantage-stocks|"
  "AAPL quote|alphavantage-stocks|"
  "intraday prices|alphavantage-stocks|"

  # Weather
  "weather|openmeteo-forecast|"
  "weather forecast|openmeteo-forecast|"
  "temperature|openmeteo-forecast|"
  "precipitation|openmeteo-forecast|"
  "wind speed|openmeteo-forecast|"

  # Reference
  "wikipedia article|wikipedia-search|"
  "encyclopedia|NONE|wikipedia-search descr doesnt mention encyclopedia"
  "wiki|wikipedia-search|"

  # Academic
  "research paper|NONE|openalex desc lacks research/paper"
  "arxiv preprint|arxiv-search|"
  "scholarly works|openalex-works|"
  "citations|openalex-works|"

  # Code
  "github repo|github-search|"
  "github issues|github-search|"
  "code search|github-search|"

  # Food
  "nutrition|openfoodfacts-product|"
  "food product|openfoodfacts-product|"
  "barcode|openfoodfacts-product|"

  # Entertainment
  "movie|tmdb-movies|"
  "movie cast|tmdb-movies|"
  "film recommendations|tmdb-movies|"

  # No-match (should return NONE)
  "haiku|NONE|no creative-writing specialist"
  "joke|NONE|"
  "math|NONE|"
  "compound interest|NONE|"
  "translation|NONE|"
  "italian translation|NONE|"
  "python hello world|NONE|"
  "regex|NONE|"
  "definition|NONE|"
  "serendipity|NONE|"
  "recipe|NONE|"
  "sql query|github-search|github-search has "query" in desc"

  # Edge cases
  "|ERR|empty topic exits early"
  "a|NONE|too-short token"
  "the|NONE|stopword-ish"
)

PASS=0; FAIL=0; ERR=0
declare -a failures
for case in "${cases[@]}"; do
    IFS='|' read -r topic expect note <<<"$case"
    actual=$(match "$topic")
    if [ "$actual" = "$expect" ]; then
        PASS=$((PASS+1))
    elif [ "$actual" = "ERR" ]; then
        ERR=$((ERR+1))
        failures+=("ERR  $topic|expect=$expect actual=$actual ($note)")
    else
        FAIL=$((FAIL+1))
        failures+=("FAIL $topic|expect=$expect actual=$actual ($note)")
    fi
done

echo
echo "=== Matcher battery: $PASS pass, $FAIL fail, $ERR err ==="
echo
for f in "${failures[@]}"; do echo "  $f"; done
