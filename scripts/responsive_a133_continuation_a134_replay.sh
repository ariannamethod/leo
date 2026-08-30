#!/usr/bin/env bash
# A.134: reproduce the frozen responsive continuation without another API call.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive A.133 continuation replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-a133-continuation-a134-replay-$STAMP}"
FROZEN="$ROOT/scripts/responsive_a133_continuation_a134_frozen.tsv"
PROMPTS="$ROOT/scripts/fixtures/responsive_a133_continuation_a134_meal.txt"
EXPECTED_PREFIX="$ROOT/scripts/responsive_a133_continuation_a134_prefix_expected.jsonl"
EXPECTED_ANATOMY="$ROOT/scripts/responsive_a133_continuation_a134_anatomy.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r life seed fixture prefix_turns api_turns prompts_sha \
    transcript_sha state_sha async_transcript_sha async_state_sha mismatches \
    references open questions < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
[ "$life" = meal ] && [ "$seed" = 617 ] && \
    [ "$fixture" = scripts/fixtures/responsive_a133_continuation_a134_meal.txt ]
[ "$prefix_turns" = 14 ] && [ "$api_turns" = 10 ]

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.134 \
        LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Continue the exact A.133 meal fork.' \
        LEO_NATURAL_ASYNC="$async" \
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

jq -c '{turn, human, leo}' "$OUT/lives/replay/dialogue.jsonl" | sed -n '1,14p' \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$EXPECTED_PREFIX" "$OUT/prefix.actual.jsonl"

cc "$ROOT/scripts/responsive_a133_continuation_a134_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/responsive-a133-continuation-fixture" -lpthread
"$OUT/responsive-a133-continuation-fixture" \
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

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$mismatches"
printf 'api_reply_references\t%s\n' "$references"
printf 'lentil_resolved_turn\t3\n'
printf 'difficult_opened_turn\t15\n'
printf 'open_wonder_turns\t%s\n' "$open"
printf 'school_questions\t%s\n' "$questions"
printf 'result\tresponsive-a133-continuation-reproduced-not-judged\n'
printf 'A.134 replay: %s\n' "$OUT"
