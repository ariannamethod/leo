#!/usr/bin/env bash
# A.147: a third wholly fresh ordinary visible-only life.
set -Eeuo pipefail

trap 'rc=$?; printf "third fresh ordinary life failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-third-fresh-ordinary-life-a147-$STAMP}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
PLAN="$ROOT/scripts/third_fresh_ordinary_life_a147_plan.tsv"
FROZEN="$ROOT/scripts/third_fresh_ordinary_life_a147_frozen.tsv"
FROZEN_PROMPTS="$ROOT/scripts/fixtures/third_fresh_ordinary_life_a147_ordinary.txt"
API_TURNS="$ROOT/scripts/third_fresh_ordinary_life_a147_api_turns.tsv"
ANATOMY="$ROOT/scripts/third_fresh_ordinary_life_a147_anatomy.tsv"
API="$OUT/lives/api"

[ -n "$KEY_FILE" ] && [ -s "$KEY_FILE" ] || {
    printf 'OPENAI_API_KEY_FILE must name a readable nonempty key file\n' >&2
    exit 2
}
[ ! -e "$OUT" ] || [ -d "$OUT" ] || {
    printf 'output path is not a directory: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/lives" "$OUT/points"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }

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

if [ ! -f "$API/dialogue.jsonl" ]; then
    OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
        LEO_NATURAL_PHASE=A.147 \
        LEO_NATURAL_QUESTION=third-fresh-ordinary-life \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=618 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Begin with one ordinary concrete observation from daily life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$API" > "$OUT/lives/api.out"
fi

jq -e '.source == "responses-api-visible-transcript" and
       .replay_prefix_turns == 0 and .api_turns == 24 and
       .api_store == false and .transcript_visible_to_interlocutor == true and
       .diagnostics_visible_to_interlocutor == false and
       .school_affirmation_role == true and
       .school_cautious_pair == true' "$API/manifest.json" >/dev/null

cmp -s "$FROZEN_PROMPTS" "$API/prompts.txt"
printf 'turn\tutterance\tstance\treply_reference\tmodel\n' \
    > "$OUT/api-turns.actual.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" }
    NR > 1 { print $3, $5, $6, $7, $8 }
' "$API/sessions.tsv" >> "$OUT/api-turns.actual.tsv"
cmp -s "$API_TURNS" "$OUT/api-turns.actual.tsv"

receipt_count=0
for response in "$API"/api/turn-*.response.json; do
    jq -e '.status == "completed" and .store == false and
           (.model | type) == "string"' "$response" >/dev/null
    receipt_count=$((receipt_count + 1))
done
[ "$receipt_count" -eq 24 ]

: > "$OUT/empty-history.jsonl"
LEO_NATURAL_REQUEST_ONLY=1 LEO_INTERLOCUTOR_MODEL="$model" \
    "$ROOT/scripts/natural_interlocutor_turn.sh" 1 \
    "$OUT/empty-history.jsonl" \
    'Begin with one ordinary concrete observation from daily life.' \
    "$OUT/turn1-request-only.json" "$OUT/turn1-request-only.response.json" \
    >/dev/null
cmp -s "$API/api/turn-01.json.request.json" \
    "$OUT/turn1-request-only.json.request.json"
[ "$(sha256_file "$OUT/turn1-request-only.json.request.json")" = \
    "$turn1_request_sha" ]
actual_hidden_terms="$(jq -r '.instructions, .input' \
    "$OUT/turn1-request-only.json.request.json" | \
    awk 'BEGIN { IGNORECASE = 1 }
         /kettle|rain|finished|somehow|caring/ { n++ }
         END { print n + 0 }')"
[ "$actual_hidden_terms" = "$hidden_prior_terms" ]

for turns in 2 9 10 12 13; do
    sed -n "1,${turns}p" "$API/prompts.txt" > "$OUT/points/turn${turns}.prompts"
    destination="$OUT/points/turn${turns}"
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$OUT/points/turn${turns}.prompts" \
            LEO_NATURAL_PHASE=A.147 \
            LEO_NATURAL_QUESTION=third-fresh-ordinary-life \
            LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=replay \
            LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
            LEO_NATURAL_OPENING='Replay the frozen third fresh ordinary life.' \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/points/turn${turns}.out"
    fi
done

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$API/prompts.txt" \
            LEO_NATURAL_PHASE=A.147 \
            LEO_NATURAL_QUESTION=third-fresh-ordinary-life \
            LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
            LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OPENING='Replay the frozen third fresh ordinary life.' \
            LEO_NATURAL_ASYNC="$async" \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/lives/$arm.out"
    fi
done

cmp -s "$API/visible_transcript.txt" "$OUT/lives/replay/visible_transcript.txt"
cmp -s "$API/state/leo.state" "$OUT/lives/replay/state/leo.state"
cmp -s "$OUT/lives/async-a/visible_transcript.txt" \
    "$OUT/lives/async-b/visible_transcript.txt"
cmp -s "$OUT/lives/async-a/state/leo.state" \
    "$OUT/lives/async-b/state/leo.state"

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

actual_mismatches="$(jq -n \
    --slurpfile sync "$OUT/lives/replay/dialogue.jsonl" \
    --slurpfile async "$OUT/lives/async-a/dialogue.jsonl" '
    [range(0; $sync | length) |
     select($sync[.].leo != $async[.].leo)] | length
')"
actual_questions="$(jq -sr '
    [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
       ascii_downcase) + "@" + (.turn | tostring))] | join(",")
' "$OUT/lives/replay/dialogue.jsonl")"
actual_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_references="$(awk -F '\t' 'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' "$API_TURNS")"
stance_count() {
    awk -F '\t' -v stance="$1" \
        'NR > 1 && $3 == stance { n++ } END { print n + 0 }' "$API_TURNS"
}
actual_kettle_openings="$(for path in \
    "$ROOT/scripts/fixtures/fresh_ordinary_life_a141_ordinary.txt" \
    "$ROOT/scripts/fixtures/second_fresh_ordinary_life_a144_ordinary.txt" \
    "$FROZEN_PROMPTS"; do sed -n '1p' "$path"; done | \
    awk 'BEGIN { IGNORECASE = 1 } /kettle/ { n++ } END { print n + 0 }')"

[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]
[ "$(sha256_file "$ANATOMY")" = "$anatomy_sha" ]
[ "$(sha256_file "$API/prompts.txt")" = "$prompts_sha" ]
[ "$(sha256_file "$API/visible_transcript.txt")" = "$transcript_sha" ]
[ "$(sha256_file "$API/state/leo.state")" = "$state_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" = \
    "$async_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/state/leo.state")" = \
    "$async_state_sha" ]
[ "$actual_mismatches" = "$mismatches" ]
[ "$actual_questions" = "$questions" ] && [ "$actual_open" = "$open_turns" ]
[ "$actual_references" = "$references" ]
[ "$(stance_count open)" = "$open_stances" ]
[ "$(stance_count follow)" = "$follow_stances" ]
[ "$(stance_count clarify)" = "$clarify_stances" ]
[ "$(stance_count answer)" = "$answer_stances" ]
[ "$(stance_count comfort)" = "$comfort_stances" ]
[ "$(sed -n "${answer_turn}p" "$API/prompts.txt")" = "$answer_prompt" ]
[ "$fresh_openings" = 3 ] && [ "$actual_kettle_openings" = "$kettle_openings" ]
[ "$final_sleep_exact" = true ]

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
printf 'A.147 third fresh ordinary life: %s\n' "$OUT"
