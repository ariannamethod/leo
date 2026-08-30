#!/usr/bin/env bash
# A.132: replay the frozen responsive meal life without another API request.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive honest Wonder replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-honest-wonder-a132-replay-$STAMP}"
FROZEN="$ROOT/scripts/responsive_honest_wonder_a132_frozen.tsv"
PROMPTS="$ROOT/scripts/fixtures/responsive_honest_wonder_a132_meal.txt"
EXPECTED_PREFIX="$ROOT/scripts/responsive_honest_wonder_a132_prefix_expected.jsonl"
EXPECTED_ANATOMY="$ROOT/scripts/responsive_honest_wonder_a132_anatomy.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r life seed fixture prefix_turns api_turns prompts_sha \
    transcript_sha state_sha async_transcript_sha async_state_sha mismatches < <(
        awk -F '\t' 'NR == 2 { print }' "$FROZEN")
[ "$life" = meal ] && [ "$seed" = 617 ] && [ "$fixture" = scripts/fixtures/responsive_honest_wonder_a132_meal.txt ]
[ "$prefix_turns" = 2 ] && [ "$api_turns" = 22 ]

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.132 \
        LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Continue the exact A.131 meal fork.' \
        LEO_NATURAL_ASYNC="$async" \
        "$ROOT/scripts/natural_life_probe.sh" "$destination" \
        > "$OUT/lives/$arm.out"
done

[ "$(sha256_file "$OUT/lives/replay/visible_transcript.txt")" = "$transcript_sha" ]
[ "$(sha256_file "$OUT/lives/replay/state/leo.state")" = "$state_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" = "$async_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/state/leo.state")" = "$async_state_sha" ]
cmp -s "$OUT/lives/async-a/visible_transcript.txt" "$OUT/lives/async-b/visible_transcript.txt"
cmp -s "$OUT/lives/async-a/state/leo.state" "$OUT/lives/async-b/state/leo.state"

jq -c '{turn, human, leo}' "$OUT/lives/replay/dialogue.jsonl" | sed -n '1,2p' \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$EXPECTED_PREFIX" "$OUT/prefix.actual.jsonl"

sed -n '1,14p' "$PROMPTS" > "$OUT/first14.txt"
LEO_NATURAL_REPLAY_FILE="$OUT/first14.txt" \
    LEO_NATURAL_PHASE=A.132 \
    LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=replay \
    LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=14 \
    LEO_NATURAL_OPENING='Continue the exact A.131 meal fork.' \
    "$ROOT/scripts/natural_life_probe.sh" "$OUT/first14" \
    > "$OUT/first14.out"
cc "$ROOT/scripts/responsive_honest_wonder_a132_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/responsive-honest-wonder-fixture" -lpthread
"$OUT/responsive-honest-wonder-fixture" \
    "$OUT/first14/state/leo.state" > "$OUT/anatomy.tsv"
cmp -s "$EXPECTED_ANATOMY" "$OUT/anatomy.tsv"

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$mismatches"
printf 'lentil_resolved_turn\t3\n'
printf 'meaningful_opened_turn\t14\n'
printf 'open_wonder_turns\t12\n'
printf 'result\tresponsive-honest-wonder-life-reproduced-not-judged\n'
printf 'A.132 replay: %s\n' "$OUT"
