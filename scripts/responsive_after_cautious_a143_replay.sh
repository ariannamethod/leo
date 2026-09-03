#!/usr/bin/env bash
# A.143: replay the frozen post-cautious responsive life without API calls.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive after cautious replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-after-cautious-a143-replay-$STAMP}"
FROZEN="$ROOT/scripts/responsive_after_cautious_a143_frozen.tsv"
PLAN="$ROOT/scripts/responsive_after_cautious_a143_plan.tsv"
PREFIX="$ROOT/scripts/fixtures/responsive_after_cautious_a143_prefix.txt"
PREFIX_EXPECTED="$ROOT/scripts/responsive_after_cautious_a143_prefix_expected.jsonl"
API_TURNS="$ROOT/scripts/responsive_after_cautious_a143_api_turns.tsv"
ANATOMY="$ROOT/scripts/responsive_after_cautious_a143_anatomy.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r life seed fixture plan_sha prefix_expected_sha \
    api_turns_sha anatomy_sha prefix_turns api_turns completed store_false \
    model prompts_sha transcript_sha state_sha async_transcript_sha \
    async_state_sha mismatches references answer_stances comfort_stances \
    follow_stances open questions question_turn question_reply answer_turn \
    answer_prompt final_pending final_wonders simply_primary \
    simply_alternate receive_primary receive_alternate \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
PROMPTS="$ROOT/$fixture"

[ "$life" = ordinary ] && [ "$seed" = 853 ]
[ "$prefix_turns" = 6 ] && [ "$api_turns" = 18 ]
[ "$completed" = 18 ] && [ "$store_false" = 18 ]
[ "$model" = gpt-5.6-luna ]
[ "$question_turn" = 19 ] && [ "$answer_turn" = 20 ]
[ "$question_reply" = 'Receive? Water or Home?' ]
[ "$answer_prompt" = \
    'Both, perhaps: water can reach home, and home can make room for it.' ]

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$PREFIX_EXPECTED")" = "$prefix_expected_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]
[ "$(sha256_file "$ANATOMY")" = "$anatomy_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

for turns in 6 19 20; do
    sed -n "1,${turns}p" "$PROMPTS" > "$OUT/turn${turns}.prompts"
    LEO_NATURAL_REPLAY_FILE="$OUT/turn${turns}.prompts" \
        LEO_NATURAL_PHASE=A.143 \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=replay \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
        LEO_NATURAL_OPENING='Replay the frozen responsive post-cautious life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/turn${turns}" \
        > "$OUT/turn${turns}.out"
done

jq -c '{turn, human, leo}' "$OUT/turn6/dialogue.jsonl" \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$PREFIX_EXPECTED" "$OUT/prefix.actual.jsonl"
cmp -s "$PREFIX" "$OUT/turn6/prompts.txt"

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.143 \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Replay the frozen responsive post-cautious life.' \
        LEO_NATURAL_ASYNC="$async" \
        "$ROOT/scripts/natural_life_probe.sh" "$destination" \
        > "$OUT/lives/$arm.out"
done

[ "$(sha256_file "$OUT/lives/replay/visible_transcript.txt")" = \
    "$transcript_sha" ]
[ "$(sha256_file "$OUT/lives/replay/state/leo.state")" = "$state_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" = \
    "$async_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/state/leo.state")" = \
    "$async_state_sha" ]
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

cc "$ROOT/scripts/responsive_after_cautious_a143_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/responsive-after-cautious-fixture" -lpthread
"$OUT/responsive-after-cautious-fixture" \
    "$OUT/turn6/state/leo.state" \
    "$OUT/turn19/state/leo.state" \
    "$OUT/turn20/state/leo.state" \
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
actual_comfort="$(awk -F '\t' 'NR > 1 && $3 == "comfort" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
actual_follow="$(awk -F '\t' 'NR > 1 && $3 == "follow" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
[ "$actual_questions" = "$questions" ] && [ "$actual_open" = "$open" ]
[ "$actual_references" = "$references" ]
[ "$actual_answers" = "$answer_stances" ]
[ "$actual_comfort" = "$comfort_stances" ]
[ "$actual_follow" = "$follow_stances" ]

awk -F '\t' -v pending="$final_pending" -v wonders="$final_wonders" \
    -v simply_primary="$simply_primary" \
    -v simply_alternate="$simply_alternate" \
    -v receive_primary="$receive_primary" \
    -v receive_alternate="$receive_alternate" '
    $1 == "turn24" && $2 == "simply" {
        if ($4 != simply_primary || $5 != simply_alternate ||
            $11 != 1 || $15 != pending || $19 != wonders) exit 2
        simply++
    }
    $1 == "turn24" && $2 == "receive" {
        if ($4 != receive_primary || $5 != receive_alternate ||
            $11 != 1 || $15 != pending || $19 != wonders) exit 2
        receive++
    }
    END { if (simply != 1 || receive != 1) exit 2 }
' "$OUT/anatomy.tsv"

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$actual_mismatches"
printf 'api_turns_frozen\t%s\n' "$api_turns"
printf 'api_reply_references\t%s\n' "$actual_references"
printf 'api_answer_stances\t%s\n' "$actual_answers"
printf 'school_questions\t%s\n' "$actual_questions"
printf 'receive_question_turn\t%s\n' "$question_turn"
printf 'receive_resolution_turn\t%s\n' "$answer_turn"
printf 'final_pending\t%s\n' "$final_pending"
printf 'result\tresponsive-after-cautious-hears-second-cautious-pair\n'
printf 'A.143 responsive after cautious replay: %s\n' "$OUT"
