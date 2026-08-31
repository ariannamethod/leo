#!/usr/bin/env bash
# A.136: reproduce the frozen difficult-return continuation without an API call.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive difficult return replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-difficult-return-a136-replay-$STAMP}"
FROZEN="$ROOT/scripts/responsive_difficult_return_a136_frozen.tsv"
PROMPTS="$ROOT/scripts/fixtures/responsive_difficult_return_a136_meal.txt"
PREFIX="$ROOT/scripts/fixtures/responsive_difficult_return_a136_prefix.txt"
API_TURNS="$ROOT/scripts/responsive_difficult_return_a136_api_turns.tsv"
EXPECTED_PREFIX="$ROOT/scripts/responsive_difficult_return_a136_prefix_expected.jsonl"
EXPECTED_ANATOMY="$ROOT/scripts/responsive_difficult_return_a136_anatomy.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r life seed fixture api_turns_sha prefix_turns api_turns \
    prompts_sha transcript_sha state_sha async_transcript_sha async_state_sha \
    mismatches references open questions first_stance first_reference \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
[ "$life" = meal ] && [ "$seed" = 617 ] && \
    [ "$fixture" = scripts/fixtures/responsive_difficult_return_a136_meal.txt ]
[ "$prefix_turns" = 25 ] && [ "$api_turns" = 10 ]

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]

LEO_NATURAL_REPLAY_FILE="$PREFIX" \
    LEO_NATURAL_PHASE=A.136 \
    LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=replay \
    LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=25 \
    LEO_NATURAL_OPENING='Reproduce the exact A.135 difficult-return fork.' \
    LEO_NATURAL_REFERENCE_PREDICATION=0 \
    LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
    "$ROOT/scripts/natural_life_probe.sh" "$OUT/prefix" \
    > "$OUT/prefix.out"

jq -c '{turn, human, leo}' "$OUT/prefix/dialogue.jsonl" \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$EXPECTED_PREFIX" "$OUT/prefix.actual.jsonl"

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.136 \
        LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=35 \
        LEO_NATURAL_OPENING='Continue the exact A.135 difficult-return fork.' \
        LEO_NATURAL_ASYNC="$async" \
        LEO_NATURAL_REFERENCE_PREDICATION=0 \
        LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$destination" \
        > "$OUT/lives/$arm.out"
done

[ "$(sha256_file "$OUT/lives/replay/visible_transcript.txt")" = "$transcript_sha" ]
[ "$(sha256_file "$OUT/lives/replay/state/leo.state")" = "$state_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" = "$async_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/state/leo.state")" = "$async_state_sha" ]
cmp -s "$OUT/lives/async-a/visible_transcript.txt" "$OUT/lives/async-b/visible_transcript.txt"
cmp -s "$OUT/lives/async-a/state/leo.state" "$OUT/lives/async-b/state/leo.state"

cc "$ROOT/scripts/responsive_difficult_return_a136_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/responsive-difficult-return-fixture" -lpthread
"$OUT/responsive-difficult-return-fixture" \
    "$OUT/prefix/state/leo.state" \
    "$OUT/lives/replay/state/leo.state" > "$OUT/anatomy.tsv"
cmp -s "$EXPECTED_ANATOMY" "$OUT/anatomy.tsv"

actual_questions="$(jq -sr '
    [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
      "@" + (.turn | tostring))] | join(",")
' "$OUT/lives/replay/dialogue.jsonl")"
actual_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
[ "$actual_questions" = "$questions" ] && [ "$actual_open" = "$open" ]
[ "$(awk -F '\t' 'NR == 2 { print $3 }' "$API_TURNS")" = "$first_stance" ]
[ "$(awk -F '\t' 'NR == 2 { print $4 }' "$API_TURNS")" = "$first_reference" ]

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$mismatches"
printf 'api_reply_references\t%s\n' "$references"
printf 'first_api_stance\t%s\n' "$first_stance"
printf 'difficult_return_turn\t25\n'
printf 'difficult_false_resolution_turn\t26\n'
printf 'open_wonder_turns\t%s\n' "$open"
printf 'school_questions\t%s\n' "$questions"
printf 'result\tresponsive-difficult-return-reproduced-not-repaired\n'
printf 'A.136 replay: %s\n' "$OUT"
