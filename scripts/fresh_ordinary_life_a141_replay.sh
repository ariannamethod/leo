#!/usr/bin/env bash
# A.141: replay one wholly fresh ordinary visible-only life without API calls.
set -Eeuo pipefail

trap 'rc=$?; printf "fresh ordinary life replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-fresh-ordinary-life-a141-replay-$STAMP}"
PLAN="$ROOT/scripts/fresh_ordinary_life_a141_plan.tsv"
FROZEN="$ROOT/scripts/fresh_ordinary_life_a141_frozen.tsv"
API_TURNS="$ROOT/scripts/fresh_ordinary_life_a141_api_turns.tsv"
ANATOMY="$ROOT/scripts/fresh_ordinary_life_a141_anatomy.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r life seed fixture plan_sha api_turns_sha anatomy_sha \
    api_turns completed store_false prompts_sha transcript_sha state_sha \
    async_transcript_sha async_state_sha mismatches references answers open \
    questions question_turn question_reply answer_turn answer_prompt \
    final_pending final_primary final_alternate final_pending_turns \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
PROMPTS="$ROOT/$fixture"

[ "$life" = ordinary ] && [ "$seed" = 853 ] && [ "$api_turns" = 24 ]
[ "$completed" = 24 ] && [ "$store_false" = 24 ]
[ "$question_turn" = 5 ] && [ "$answer_turn" = 6 ]
[ "$question_reply" = 'Simply? Light or Now?' ]
[ "$answer_prompt" = 'Both, maybe: the light is here now, and we can simply listen.' ]

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]
[ "$(sha256_file "$ANATOMY")" = "$anatomy_sha" ]

sed -n '1,5p' "$PROMPTS" > "$OUT/turn5.prompts"
sed -n '1,6p' "$PROMPTS" > "$OUT/turn6.prompts"
for turns in 5 6; do
    LEO_NATURAL_REPLAY_FILE="$OUT/turn$turns.prompts" \
        LEO_NATURAL_PHASE=A.141 \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=replay \
        LEO_NATURAL_CAUTIOUS_PAIR=0 \
        LEO_NATURAL_SEED=853 LEO_NATURAL_TURNS="$turns" \
        LEO_NATURAL_OPENING='Replay the frozen A.141 ordinary life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/turn$turns" \
        > "$OUT/turn$turns.out"
done

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.141 \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_CAUTIOUS_PAIR=0 \
        LEO_NATURAL_SEED=853 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Replay the frozen A.141 ordinary life.' \
        LEO_NATURAL_ASYNC="$async" \
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

actual_mismatches="$(jq -n \
    --slurpfile sync "$OUT/lives/replay/dialogue.jsonl" \
    --slurpfile async "$OUT/lives/async-a/dialogue.jsonl" '
    [range(0; $sync | length) |
     select($sync[.].leo != $async[.].leo)] | length
')"
[ "$actual_mismatches" = "$mismatches" ]

cc "$ROOT/scripts/fresh_ordinary_life_a141_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/fresh-ordinary-life-fixture" -lpthread
"$OUT/fresh-ordinary-life-fixture" \
    "$OUT/turn5/state/leo.state" \
    "$OUT/turn6/state/leo.state" \
    "$OUT/lives/replay/state/leo.state" > "$OUT/anatomy.tsv"
cmp -s "$ANATOMY" "$OUT/anatomy.tsv" || {
    diff -u "$ANATOMY" "$OUT/anatomy.tsv" >&2 || true
    exit 2
}

actual_questions="$(jq -sr '
    [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
      "@" + (.turn | tostring))] | join(",")
' "$OUT/lives/replay/dialogue.jsonl")"
actual_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_references="$(awk -F '\t' 'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
actual_answers="$(awk -F '\t' 'NR > 1 && $3 == "answer" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
[ "$actual_questions" = "$questions" ] && [ "$actual_open" = "$open" ]
[ "$actual_references" = "$references" ] && [ "$actual_answers" = "$answers" ]

awk -F '\t' -v pending="$final_pending" -v primary="$final_primary" \
    -v alternate="$final_alternate" -v pending_turns="$final_pending_turns" '
    $1 == "turn24" {
        if ($10 != pending || $11 != primary || $12 != alternate ||
            $13 != pending_turns || $4 != "none" || $5 != "none" ||
            $8 != 0) exit 2
        found++
    }
    END { if (found != 1) exit 2 }
' "$OUT/anatomy.tsv"

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$actual_mismatches"
printf 'api_reply_references\t%s\n' "$actual_references"
printf 'api_answer_stances\t%s\n' "$actual_answers"
printf 'school_questions\t%s\n' "$actual_questions"
printf 'natural_answer_turn\t%s\n' "$answer_turn"
printf 'final_pending\t%s\n' "$final_pending"
printf 'result\tfresh-ordinary-life-exposes-qualified-both-gap\n'
printf 'A.141 fresh ordinary life replay: %s\n' "$OUT"
