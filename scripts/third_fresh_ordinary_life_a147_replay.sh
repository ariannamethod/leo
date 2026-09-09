#!/usr/bin/env bash
# A.147: replay the third wholly fresh ordinary life without API calls.
set -Eeuo pipefail

trap 'rc=$?; printf "third fresh ordinary life replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-third-fresh-ordinary-life-a147-replay-$STAMP}"
PLAN="$ROOT/scripts/third_fresh_ordinary_life_a147_plan.tsv"
FROZEN="$ROOT/scripts/third_fresh_ordinary_life_a147_frozen.tsv"
API_TURNS="$ROOT/scripts/third_fresh_ordinary_life_a147_api_turns.tsv"
ANATOMY="$ROOT/scripts/third_fresh_ordinary_life_a147_anatomy.tsv"

IFS=$'\t' read -r phase seed fixture plan_sha api_turns_sha anatomy_sha \
    turn1_request_sha api_turns completed store_false model prompts_sha \
    transcript_sha state_sha async_transcript_sha async_state_sha \
    mismatches references open_stances follow_stances clarify_stances \
    answer_stances comfort_stances open_turns questions first_question_turn \
    first_question_reply second_question_turn second_question_reply \
    third_question_turn third_question_reply answer_turn answer_prompt \
    final_pending final_wonders final_school_learned final_deferred \
    final_deferred_word finished_heard finished_resolved shelter_heard \
    shelter_primary shelter_alternate shelter_returns yes_episode \
    final_sleep_exact fresh_openings kettle_openings hidden_prior_terms \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
PROMPTS="$ROOT/$fixture"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$phase" = A.147 ] && [ "$seed" = 618 ]
[ "$api_turns" = 24 ] && [ "$completed" = 24 ] && [ "$store_false" = 24 ]
[ "$model" = gpt-5.6-luna ] && [ "$final_sleep_exact" = true ]
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]
[ "$(sha256_file "$ANATOMY")" = "$anatomy_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/points" "$OUT/lives"

: > "$OUT/empty-history.jsonl"
LEO_NATURAL_REQUEST_ONLY=1 LEO_INTERLOCUTOR_MODEL="$model" \
    "$ROOT/scripts/natural_interlocutor_turn.sh" 1 \
    "$OUT/empty-history.jsonl" \
    'Begin with one ordinary concrete observation from daily life.' \
    "$OUT/turn1-request-only.json" "$OUT/turn1-request-only.response.json" \
    >/dev/null
[ "$(sha256_file "$OUT/turn1-request-only.json.request.json")" = \
    "$turn1_request_sha" ]
actual_hidden_terms="$(jq -r '.instructions, .input' \
    "$OUT/turn1-request-only.json.request.json" | \
    awk 'BEGIN { IGNORECASE = 1 }
         /kettle|rain|finished|somehow|caring/ { n++ }
         END { print n + 0 }')"
[ "$actual_hidden_terms" = "$hidden_prior_terms" ]

for turns in 2 9 10 12 13; do
    sed -n "1,${turns}p" "$PROMPTS" > "$OUT/points/turn${turns}.prompts"
    LEO_NATURAL_REPLAY_FILE="$OUT/points/turn${turns}.prompts" \
        LEO_NATURAL_PHASE=A.147 \
        LEO_NATURAL_QUESTION=third-fresh-ordinary-life \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=replay \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
        LEO_NATURAL_OPENING='Replay the frozen third fresh ordinary life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/points/turn${turns}" \
        > "$OUT/points/turn${turns}.out"
done

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.147 \
        LEO_NATURAL_QUESTION=third-fresh-ordinary-life \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Replay the frozen third fresh ordinary life.' \
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

cc "$ROOT/scripts/third_fresh_ordinary_life_a147_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/fixture" -lpthread
"$OUT/fixture" \
    "$OUT/points/turn2/state/leo.state" \
    "$OUT/points/turn9/state/leo.state" \
    "$OUT/points/turn10/state/leo.state" \
    "$OUT/points/turn12/state/leo.state" \
    "$OUT/points/turn13/state/leo.state" \
    "$OUT/lives/replay/state/leo.state" \
    "$OUT/turn24-sleep.state" > "$OUT/anatomy.tsv"
cmp -s "$ANATOMY" "$OUT/anatomy.tsv" || {
    diff -u "$ANATOMY" "$OUT/anatomy.tsv" >&2 || true
    exit 2
}
cmp -s "$OUT/lives/replay/state/leo.state" "$OUT/turn24-sleep.state"
"$OUT/fixture" \
    "$OUT/points/turn2/state/leo.state" \
    "$OUT/points/turn9/state/leo.state" \
    "$OUT/points/turn10/state/leo.state" \
    "$OUT/points/turn12/state/leo.state" \
    "$OUT/points/turn13/state/leo.state" \
    "$OUT/lives/async-a/state/leo.state" \
    "$OUT/turn24-async-sleep.state" > "$OUT/anatomy.async.tsv"
cmp -s "$ANATOMY" "$OUT/anatomy.async.tsv"

actual_questions="$(jq -sr '
    [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
       ascii_downcase) + "@" + (.turn | tostring))] | join(",")
' "$OUT/lives/replay/dialogue.jsonl")"
actual_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_references="$(awk -F '\t' 'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
stance_count() {
    awk -F '\t' -v stance="$1" \
        'NR > 1 && $3 == stance { n++ } END { print n + 0 }' "$API_TURNS"
}
actual_kettle_openings="$(for path in \
    "$ROOT/scripts/fixtures/fresh_ordinary_life_a141_ordinary.txt" \
    "$ROOT/scripts/fixtures/second_fresh_ordinary_life_a144_ordinary.txt" \
    "$PROMPTS"; do sed -n '1p' "$path"; done | \
    awk 'BEGIN { IGNORECASE = 1 } /kettle/ { n++ } END { print n + 0 }')"

[ "$actual_questions" = "$questions" ] && [ "$actual_open" = "$open_turns" ]
[ "$actual_references" = "$references" ]
[ "$(stance_count open)" = "$open_stances" ]
[ "$(stance_count follow)" = "$follow_stances" ]
[ "$(stance_count clarify)" = "$clarify_stances" ]
[ "$(stance_count answer)" = "$answer_stances" ]
[ "$(stance_count comfort)" = "$comfort_stances" ]
[ "$(sed -n "${answer_turn}p" "$PROMPTS")" = "$answer_prompt" ]
[ "$fresh_openings" = 3 ] && [ "$actual_kettle_openings" = "$kettle_openings" ]

awk -F '\t' -v pending="$final_pending" -v wonders="$final_wonders" \
    -v learned="$final_school_learned" -v deferred="$final_deferred" \
    -v deferred_word="$final_deferred_word" -v fh="$finished_heard" \
    -v fr="$finished_resolved" -v sh="$shelter_heard" \
    -v primary="$shelter_primary" -v alternate="$shelter_alternate" \
    -v returns="$shelter_returns" '
    $1 == "turn24" && $2 == "finished" {
        if ($3 != fh || $11 != fr || $13 != pending || $17 != wonders ||
            $18 != learned || $19 != 1 || $23 != deferred) exit 2
        finished++
    }
    $1 == "turn24" && $2 == "shelter" {
        if ($3 != sh || $4 != primary || $5 != alternate || $11 != 1 ||
            $12 != returns || $13 != pending || $17 != wonders ||
            $18 != learned || $19 != 0 || $23 != deferred) exit 2
        shelter++
    }
    END { if (finished != 1 || shelter != 1) exit 2 }
' "$OUT/anatomy.tsv"
[ "$final_deferred_word" = finished ] && [ "$yes_episode" = 0 ]

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_school_anatomy_exact\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$actual_mismatches"
printf 'api_reply_references\t%s\n' "$actual_references"
printf 'school_questions\t%s\n' "$actual_questions"
printf 'shelter_answer_turn\t%s\n' "$answer_turn"
printf 'final_pending\t%s\n' "$final_pending"
printf 'final_deferred\t%s\n' "$final_deferred_word"
printf 'generic_openings_with_kettle\t%s/%s\n' "$actual_kettle_openings" "$fresh_openings"
printf 'result\tthird-fresh-life-learns-shelter-and-exposes-interlocutor-opening-collapse\n'
printf 'A.147 third fresh ordinary life replay: %s\n' "$OUT"
