#!/usr/bin/env bash
# A.146: replay the frozen post-affirmation responsive life without API calls.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive after affirmation replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-after-affirmation-a146-replay-$STAMP}"
PLAN="$ROOT/scripts/responsive_after_affirmation_a146_plan.tsv"
FROZEN="$ROOT/scripts/responsive_after_affirmation_a146_frozen.tsv"
PREFIX_EXPECTED="$ROOT/scripts/responsive_after_affirmation_a146_prefix_expected.jsonl"
API_TURNS="$ROOT/scripts/responsive_after_affirmation_a146_api_turns.tsv"
ANATOMY="$ROOT/scripts/responsive_after_affirmation_a146_anatomy.tsv"

IFS=$'\t' read -r phase seed fixture plan_sha prefix_expected_sha \
    api_turns_sha anatomy_sha prefix_turns api_turns completed store_false \
    model prompts_sha transcript_sha state_sha async_transcript_sha \
    async_state_sha mismatches references follow_stances clarify_stances \
    comfort_stances answer_stances questions continuation_questions \
    open_turns final_pending final_pending_turns final_wonders final_deferred \
    final_deferred_word finished_heard somehow_heard yeah_heard \
    finished_resolved somehow_episode yeah_episode final_sleep_exact \
    first_continuation_human first_continuation_leo \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
PROMPTS="$ROOT/$fixture"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$phase" = A.146 ] && [ "$seed" = 542 ]
[ "$prefix_turns" = 6 ] && [ "$api_turns" = 18 ]
[ "$completed" = 18 ] && [ "$store_false" = 18 ]
[ "$model" = gpt-5.6-luna ] && [ "$final_sleep_exact" = true ]
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$PREFIX_EXPECTED")" = "$prefix_expected_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]
[ "$(sha256_file "$ANATOMY")" = "$anatomy_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/points" "$OUT/lives"

for turns in 6 7; do
    sed -n "1,${turns}p" "$PROMPTS" > "$OUT/points/turn${turns}.prompts"
    LEO_NATURAL_REPLAY_FILE="$OUT/points/turn${turns}.prompts" \
        LEO_NATURAL_PHASE=A.146 \
        LEO_NATURAL_QUESTION=responsive-after-affirmation \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=replay \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
        LEO_NATURAL_OPENING='Replay the frozen responsive post-affirmation life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/points/turn${turns}" \
        > "$OUT/points/turn${turns}.out"
done

jq -c '{turn, human, leo}' "$OUT/points/turn6/dialogue.jsonl" \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$PREFIX_EXPECTED" "$OUT/prefix.actual.jsonl"
[ "$(sha256_file "$OUT/points/turn6/visible_transcript.txt")" = \
    "$(awk -F '\t' '$1 == "source_transcript_sha256" { print $2 }' "$PLAN")" ]
[ "$(sha256_file "$OUT/points/turn6/state/leo.state")" = \
    "$(awk -F '\t' '$1 == "source_state_sha256" { print $2 }' "$PLAN")" ]

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.146 \
        LEO_NATURAL_QUESTION=responsive-after-affirmation \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Replay the frozen responsive post-affirmation life.' \
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

cc "$ROOT/scripts/responsive_after_affirmation_a146_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/fixture" -lpthread
"$OUT/fixture" \
    "$OUT/points/turn6/state/leo.state" \
    "$OUT/points/turn7/state/leo.state" \
    "$OUT/lives/replay/state/leo.state" \
    "$OUT/turn24-sleep.state" > "$OUT/anatomy.tsv"
cmp -s "$ANATOMY" "$OUT/anatomy.tsv" || {
    diff -u "$ANATOMY" "$OUT/anatomy.tsv" >&2 || true
    exit 2
}
cmp -s "$OUT/lives/replay/state/leo.state" "$OUT/turn24-sleep.state"
"$OUT/fixture" \
    "$OUT/points/turn6/state/leo.state" \
    "$OUT/points/turn7/state/leo.state" \
    "$OUT/lives/async-a/state/leo.state" \
    "$OUT/turn24-async-sleep.state" > "$OUT/anatomy.async.tsv"
cmp -s "$ANATOMY" "$OUT/anatomy.async.tsv"
cmp -s "$OUT/lives/async-a/state/leo.state" \
    "$OUT/turn24-async-sleep.state"

actual_questions="$(jq -sr '
    [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
       ascii_downcase) + "@" + (.turn | tostring))] | join(",")
' "$OUT/lives/replay/dialogue.jsonl")"
actual_continuation_questions="$(jq -sr '
    [.[] | select(.turn >= 7 and (.leo | test("^[[:alpha:]]+\\?"))) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
       ascii_downcase) + "@" + (.turn | tostring))] |
    if length == 0 then "none" else join(",") end
' "$OUT/lives/replay/dialogue.jsonl")"
actual_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_references="$(awk -F '\t' 'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
actual_follow="$(awk -F '\t' 'NR > 1 && $3 == "follow" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
actual_clarify="$(awk -F '\t' 'NR > 1 && $3 == "clarify" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
actual_comfort="$(awk -F '\t' 'NR > 1 && $3 == "comfort" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
actual_answers="$(awk -F '\t' 'NR > 1 && $3 == "answer" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
actual_first_human="$(jq -r 'select(.turn == 7) | .human' "$OUT/lives/replay/dialogue.jsonl")"
actual_first_leo="$(jq -r 'select(.turn == 7) | .leo' "$OUT/lives/replay/dialogue.jsonl")"

[ "$actual_questions" = "$questions" ]
[ "$actual_continuation_questions" = "$continuation_questions" ]
[ "$actual_open" = "$open_turns" ]
[ "$actual_references" = "$references" ]
[ "$actual_follow" = "$follow_stances" ]
[ "$actual_clarify" = "$clarify_stances" ]
[ "$actual_comfort" = "$comfort_stances" ]
[ "$actual_answers" = "$answer_stances" ]
[ "$actual_first_human" = "$first_continuation_human" ]
[ "$actual_first_leo" = "$first_continuation_leo" ]

awk -F '\t' -v pending="$final_pending" \
    -v pending_turns="$final_pending_turns" -v wonders="$final_wonders" \
    -v deferred="$final_deferred" -v deferred_word="$final_deferred_word" \
    -v fh="$finished_heard" -v sh="$somehow_heard" -v yh="$yeah_heard" \
    -v resolved="$finished_resolved" -v se="$somehow_episode" \
    -v ye="$yeah_episode" '
    $1 == "turn24" && $2 == "finished" {
        if ($3 != fh || $11 != resolved || $13 != pending ||
            $14 != pending_turns || $15 != wonders) exit 2
        finished++
    }
    $1 == "turn24" && $2 == "somehow" {
        if ($3 != sh || $6 != se || $13 != pending || $14 != pending_turns ||
            $15 != wonders || $16 != 1) exit 2
        somehow++
    }
    $1 == "turn24" && $2 == "yeah" {
        if ($3 != yh || $6 != ye || $13 != pending ||
            $14 != pending_turns || $15 != wonders) exit 2
        yeah++
    }
    END { if (finished != 1 || somehow != 1 || yeah != 1) exit 2 }
' "$OUT/anatomy.tsv"
[ "$final_deferred" = 1 ] && [ "$final_deferred_word" = somehow ]

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_school_anatomy_exact\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$actual_mismatches"
printf 'api_turns_frozen\t%s\n' "$api_turns"
printf 'api_reply_references\t%s\n' "$actual_references"
printf 'school_questions\t%s\n' "$actual_questions"
printf 'continuation_questions\t%s\n' "$actual_continuation_questions"
printf 'final_pending\t%s\n' "$final_pending"
printf 'final_deferred\t%s\n' "$final_deferred_word"
printf 'result\tpost-affirmation-mouth-continues-without-shifted-interruption\n'
printf 'A.146 responsive after affirmation replay: %s\n' "$OUT"
