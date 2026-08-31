#!/usr/bin/env bash
# A.138: replay the frozen repaired-Difficult continuation without an API call.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive difficult after repair replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-difficult-after-repair-a138-replay-$STAMP}"
FROZEN="$ROOT/scripts/responsive_difficult_after_repair_a138_frozen.tsv"
PLAN="$ROOT/scripts/responsive_difficult_after_repair_a138_plan.tsv"
PROMPTS="$ROOT/scripts/fixtures/responsive_difficult_after_repair_a138_meal.txt"
PREFIX="$ROOT/scripts/fixtures/responsive_difficult_return_a136_prefix.txt"
API_TURNS="$ROOT/scripts/responsive_difficult_after_repair_a138_api_turns.tsv"
EXPECTED_PREFIX="$ROOT/scripts/responsive_difficult_return_a136_prefix_expected.jsonl"
EXPECTED_ANATOMY="$ROOT/scripts/responsive_difficult_after_repair_a138_anatomy.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r life seed fixture plan_sha api_turns_sha prefix_turns \
    api_turns prompts_sha transcript_sha state_sha async_transcript_sha \
    async_state_sha mismatches references answer_stances open questions \
    first_stance first_reference difficult_heard difficult_learned \
    difficult_answer difficult_resolved difficult_returns pending \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
[ "$life" = meal ] && [ "$seed" = 617 ] && \
    [ "$fixture" = scripts/fixtures/responsive_difficult_after_repair_a138_meal.txt ]
[ "$prefix_turns" = 25 ] && [ "$api_turns" = 10 ]

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]

LEO_NATURAL_REPLAY_FILE="$PREFIX" \
    LEO_NATURAL_PHASE=A.138 \
    LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=replay \
    LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=25 \
    LEO_NATURAL_OPENING='Reproduce the exact repaired difficult-return fork.' \
    LEO_NATURAL_REFERENCE_PREDICATION=1 \
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
        LEO_NATURAL_PHASE=A.138 \
        LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=35 \
        LEO_NATURAL_OPENING='Continue the exact repaired difficult-return fork.' \
        LEO_NATURAL_ASYNC="$async" \
        LEO_NATURAL_REFERENCE_PREDICATION=1 \
        LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$destination" \
        > "$OUT/lives/$arm.out"
done

[ "$(sha256_file "$OUT/lives/replay/visible_transcript.txt")" = "$transcript_sha" ]
[ "$(sha256_file "$OUT/lives/replay/state/leo.state")" = "$state_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" = "$async_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/state/leo.state")" = "$async_state_sha" ]
cmp -s "$OUT/lives/async-a/visible_transcript.txt" \
    "$OUT/lives/async-b/visible_transcript.txt"
cmp -s "$OUT/lives/async-a/state/leo.state" \
    "$OUT/lives/async-b/state/leo.state"

cc "$ROOT/scripts/responsive_difficult_after_repair_a138_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/responsive-difficult-after-repair-fixture" -lpthread
"$OUT/responsive-difficult-after-repair-fixture" \
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
actual_references="$(awk -F '\t' 'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' "$API_TURNS")"
actual_answers="$(awk -F '\t' 'NR > 1 && $3 == "answer" { n++ } END { print n + 0 }' "$API_TURNS")"
[ "$actual_questions" = "$questions" ] && [ "$actual_open" = "$open" ]
[ "$actual_references" = "$references" ] && [ "$actual_answers" = "$answer_stances" ]
[ "$(awk -F '\t' 'NR == 2 { print $3 }' "$API_TURNS")" = "$first_stance" ]
[ "$(awk -F '\t' 'NR == 2 { print $4 }' "$API_TURNS")" = "$first_reference" ]

awk -F '\t' -v heard="$difficult_heard" -v learned="$difficult_learned" \
    -v answer="$difficult_answer" -v resolved="$difficult_resolved" \
    -v returns="$difficult_returns" -v pending="$pending" '
    $1 == "turn35" {
        if ($3 != heard || $4 != learned || $5 != answer ||
            $6 != resolved || $7 != returns || $8 != pending) exit 2
        found++
    }
    END { if (found != 1) exit 2 }
' "$OUT/anatomy.tsv"

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$mismatches"
printf 'api_reply_references\t%s\n' "$references"
printf 'api_answer_stances\t%s\n' "$answer_stances"
printf 'first_api_stance\t%s\n' "$first_stance"
printf 'difficult_return_turn\t25\n'
printf 'difficult_resolution_turn\tnone\n'
printf 'open_wonder_turns\t%s\n' "$open"
printf 'school_questions\t%s\n' "$questions"
printf 'result\tresponsive-difficult-after-repair-remains-honest\n'
printf 'A.138 replay: %s\n' "$OUT"
