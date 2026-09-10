#!/usr/bin/env bash
# A.148: one human-authored opening followed by a visible-only API life.
set -Eeuo pipefail

trap 'rc=$?; printf "human-first ordinary life failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-human-first-ordinary-life-a148-$STAMP}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
PLAN="$ROOT/scripts/human_first_ordinary_life_a148_plan.tsv"
FROZEN="$ROOT/scripts/human_first_ordinary_life_a148_frozen.tsv"
HUMAN="$ROOT/scripts/fixtures/human_first_ordinary_life_a148_turn1.txt"
PROMPTS="$ROOT/scripts/fixtures/human_first_ordinary_life_a148_ordinary.txt"
API_TURNS="$ROOT/scripts/human_first_ordinary_life_a148_api_turns.tsv"
ANATOMY="$ROOT/scripts/human_first_ordinary_life_a148_anatomy.tsv"

[ -n "$KEY_FILE" ] && [ -s "$KEY_FILE" ] || {
    printf 'OPENAI_API_KEY_FILE must name a readable nonempty key file\n' >&2
    exit 2
}
[ ! -e "$OUT" ] || [ -d "$OUT" ] || {
    printf 'output path is not a directory: %s\n' "$OUT" >&2
    exit 2
}

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }

IFS=$'\t' read -r phase seed fixture human_fixture plan_sha human_sha \
    api_turns_sha anatomy_sha turn2_request_sha human_turns api_turns \
    completed store_false model prompts_sha transcript_sha state_sha \
    async_transcript_sha async_state_sha mismatches references open_stances \
    follow_stances clarify_stances answer_stances comfort_stances \
    challenge_stances shift_stances close_stances open_turns \
    visible_question_turns questions first_school_turn first_school_reply \
    final_pending final_wonders final_school_learned final_deferred \
    final_deferred_word mysterious_heard mysterious_resolved \
    mysterious_returns mysterious_pending_turns smooth_heard smooth_episode \
    smooth_deferred smooth_blocks smooth_born_turn smooth_last_seen_turn \
    final_sleep_exact api_turn1_absent opening_contains_kettle state_births \
    state_updates state_replacements turn1_reply \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")

[ "$phase" = A.148 ] && [ "$seed" = 615 ]
[ "$ROOT/$fixture" = "$PROMPTS" ] && [ "$ROOT/$human_fixture" = "$HUMAN" ]
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$HUMAN")" = "$human_sha" ]

if [ ! -f "$OUT/dialogue.jsonl" ]; then
    [ ! -e "$OUT" ] || {
        printf 'existing output has no dialogue receipt: %s\n' "$OUT" >&2
        exit 2
    }
    LEO_NATURAL_REPLAY_FILE="$HUMAN" \
        LEO_NATURAL_PHASE=A.148 LEO_NATURAL_LIFE=ordinary \
        LEO_NATURAL_ARM=api LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=1 \
        LEO_NATURAL_OPENING='Human-authored turn 1; API begins at turn 2.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT"
fi

mkdir -p "$OUT/lives" "$OUT/points"
done_turns="$(wc -l < "$OUT/dialogue.jsonl" | tr -d ' ')"
if [ "$done_turns" -eq 1 ]; then
    cmp -s "$HUMAN" "$OUT/prompts.txt"
    [ "$(jq -r .leo "$OUT/dialogue.jsonl")" = "$turn1_reply" ]
    OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
        LEO_NATURAL_PHASE=A.148 LEO_NATURAL_LIFE=ordinary \
        LEO_NATURAL_ARM=api LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Human-authored turn 1; API begins at turn 2.' \
        LEO_NATURAL_RESUME=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT" > "$OUT/lives/api.out"
elif [ "$done_turns" -ne 24 ]; then
    printf 'unexpected completed turn count: %s\n' "$done_turns" >&2
    exit 2
fi

jq -e '.source == "frozen-prefix-then-responses-api-visible-transcript" and
       .process_resumed == true and .resumed_at_turn == 2 and
       .replay_prefix_turns == 1 and .api_turns == 23 and
       .api_store == false and .transcript_visible_to_interlocutor == true and
       .diagnostics_visible_to_interlocutor == false and
       .school_affirmation_role == true and
       .school_cautious_pair == true' "$OUT/manifest.json" >/dev/null

cmp -s "$PROMPTS" "$OUT/prompts.txt"
cmp -s "$HUMAN" <(sed -n '1p' "$OUT/prompts.txt")
printf 'turn\tutterance\tstance\treply_reference\tmodel\n' \
    > "$OUT/api-turns.actual.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" }
    NR > 1 && $3 >= 2 { print $3, $5, $6, $7, $8 }
' "$OUT/sessions.tsv" >> "$OUT/api-turns.actual.tsv"
cmp -s "$API_TURNS" "$OUT/api-turns.actual.tsv"

receipt_count=0
for response in "$OUT"/api/turn-*.response.json; do
    jq -e '.status == "completed" and .store == false and
           (.model | type) == "string"' "$response" >/dev/null
    receipt_count=$((receipt_count + 1))
done
[ "$receipt_count" -eq 23 ]
[ ! -e "$OUT/api/turn-01.json" ]
[ ! -e "$OUT/api/turn-01.response.json" ]

sed -n '1p' "$OUT/dialogue.jsonl" > "$OUT/points/turn1-history.jsonl"
LEO_NATURAL_REQUEST_ONLY=1 LEO_INTERLOCUTOR_MODEL="$model" \
    "$ROOT/scripts/natural_interlocutor_turn.sh" 2 \
    "$OUT/points/turn1-history.jsonl" \
    'Human-authored turn 1; API begins at turn 2.' \
    "$OUT/turn2-request-only.json" "$OUT/turn2-request-only.response.json" \
    >/dev/null
cmp -s "$OUT/api/turn-02.json.request.json" \
    "$OUT/turn2-request-only.json.request.json"
[ "$(sha256_file "$OUT/turn2-request-only.json.request.json")" = \
    "$turn2_request_sha" ]
actual_hidden_kettle="$(jq -r '.instructions, .input' \
    "$OUT/turn2-request-only.json.request.json" | \
    awk 'BEGIN { IGNORECASE = 1 } /kettle/ { n++ } END { print n + 0 }')"
[ "$actual_hidden_kettle" = 0 ]

for turns in 1 13 14 22 23 24; do
    sed -n "1,${turns}p" "$OUT/prompts.txt" \
        > "$OUT/points/turn${turns}.prompts"
    destination="$OUT/points/turn${turns}"
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$OUT/points/turn${turns}.prompts" \
            LEO_NATURAL_PHASE=A.148 LEO_NATURAL_LIFE=ordinary \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS="$turns" \
            LEO_NATURAL_OPENING='Replay the frozen human-first ordinary life.' \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/points/turn${turns}.out"
    fi
done

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$OUT/prompts.txt" \
            LEO_NATURAL_PHASE=A.148 LEO_NATURAL_LIFE=ordinary \
            LEO_NATURAL_ARM="$arm" LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OPENING='Replay the frozen human-first ordinary life.' \
            LEO_NATURAL_ASYNC="$async" \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/lives/$arm.out"
    fi
done

cmp -s "$OUT/visible_transcript.txt" \
    "$OUT/lives/replay/visible_transcript.txt"
cmp -s "$OUT/state/leo.state" "$OUT/lives/replay/state/leo.state"
cmp -s "$OUT/lives/async-a/visible_transcript.txt" \
    "$OUT/lives/async-b/visible_transcript.txt"
cmp -s "$OUT/lives/async-a/state/leo.state" \
    "$OUT/lives/async-b/state/leo.state"

cc "$ROOT/scripts/human_first_ordinary_life_a148_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/fixture" -lpthread
"$OUT/fixture" \
    "$OUT/points/turn1/state/leo.state" \
    "$OUT/points/turn13/state/leo.state" \
    "$OUT/points/turn14/state/leo.state" \
    "$OUT/points/turn22/state/leo.state" \
    "$OUT/points/turn23/state/leo.state" \
    "$OUT/lives/replay/state/leo.state" \
    "$OUT/turn24-sleep.state" > "$OUT/anatomy.tsv"
cmp -s "$ANATOMY" "$OUT/anatomy.tsv" || {
    diff -u "$ANATOMY" "$OUT/anatomy.tsv" >&2 || true
    exit 2
}
cmp -s "$OUT/lives/replay/state/leo.state" "$OUT/turn24-sleep.state"
"$OUT/fixture" \
    "$OUT/points/turn1/state/leo.state" \
    "$OUT/points/turn13/state/leo.state" \
    "$OUT/points/turn14/state/leo.state" \
    "$OUT/points/turn22/state/leo.state" \
    "$OUT/points/turn23/state/leo.state" \
    "$OUT/lives/async-a/state/leo.state" \
    "$OUT/turn24-async-sleep.state" > "$OUT/anatomy.async.tsv"
cmp -s "$ANATOMY" "$OUT/anatomy.async.tsv"
cmp -s "$OUT/lives/async-a/state/leo.state" \
    "$OUT/turn24-async-sleep.state"

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
async_questions="$(jq -sr '
    [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
       ascii_downcase) + "@" + (.turn | tostring))] | join(",")
' "$OUT/lives/async-a/dialogue.jsonl")"
actual_visible_questions="$(jq -sr \
    '[.[] | select(.leo | contains("?"))] | length' \
    "$OUT/lives/replay/dialogue.jsonl")"
actual_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_births="$(awk -F '\t' '$1 == "state_births" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_updates="$(awk -F '\t' '$1 == "state_updates" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_replacements="$(awk -F '\t' '$1 == "state_replacements" { print $2 }' \
    "$OUT/lives/replay/summary.txt")"
actual_references="$(awk -F '\t' \
    'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' "$API_TURNS")"
stance_count() {
    awk -F '\t' -v stance="$1" \
        'NR > 1 && $3 == stance { n++ } END { print n + 0 }' "$API_TURNS"
}

[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]
[ "$(sha256_file "$ANATOMY")" = "$anatomy_sha" ]
[ "$(sha256_file "$OUT/prompts.txt")" = "$prompts_sha" ]
[ "$(sha256_file "$OUT/visible_transcript.txt")" = "$transcript_sha" ]
[ "$(sha256_file "$OUT/state/leo.state")" = "$state_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" = \
    "$async_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/state/leo.state")" = \
    "$async_state_sha" ]
[ "$actual_mismatches" = "$mismatches" ]
[ "$actual_references" = "$references" ]
[ "$(stance_count open)" = "$open_stances" ]
[ "$(stance_count follow)" = "$follow_stances" ]
[ "$(stance_count clarify)" = "$clarify_stances" ]
[ "$(stance_count answer)" = "$answer_stances" ]
[ "$(stance_count comfort)" = "$comfort_stances" ]
[ "$(stance_count challenge)" = "$challenge_stances" ]
[ "$(stance_count shift)" = "$shift_stances" ]
[ "$(stance_count close)" = "$close_stances" ]
[ "$actual_open" = "$open_turns" ]
[ "$actual_visible_questions" = "$visible_question_turns" ]
[ "$actual_questions" = "$questions" ] && [ "$async_questions" = "$questions" ]
[ "$actual_births" = "$state_births" ]
[ "$actual_updates" = "$state_updates" ]
[ "$actual_replacements" = "$state_replacements" ]
[ "$final_sleep_exact" = true ] && [ "$api_turn1_absent" = true ]
[ "$opening_contains_kettle" = false ]

awk -F '\t' -v pending="$final_pending" -v wonders="$final_wonders" \
    -v learned="$final_school_learned" -v deferred="$final_deferred" \
    -v mh="$mysterious_heard" -v mr="$mysterious_resolved" \
    -v mret="$mysterious_returns" -v mpt="$mysterious_pending_turns" \
    -v sh="$smooth_heard" -v se="$smooth_episode" \
    -v sd="$smooth_deferred" -v sb="$smooth_blocks" \
    -v born="$smooth_born_turn" -v seen="$smooth_last_seen_turn" '
    $1 == "turn24" && $2 == "mysterious" {
        if ($3 != mh || $6 != 1 || $11 != mr || $12 != mret ||
            $13 != pending || $16 != mpt || $17 != wonders ||
            $18 != learned || $23 != deferred) exit 2
        mysterious++
    }
    $1 == "turn24" && $2 == "smooth" {
        if ($3 != sh || $6 != se || $13 != pending || $17 != wonders ||
            $18 != learned || $19 != sd || $20 != sb || $21 != born ||
            $22 != seen || $23 != deferred) exit 2
        smooth++
    }
    END { if (mysterious != 1 || smooth != 1) exit 2 }
' "$OUT/anatomy.tsv"
[ "$final_deferred_word" = smooth ]

printf 'metric\tvalue\n'
printf 'human_opening_exact\ttrue\n'
printf 'api_first_turn\t2\n'
printf 'api_turns_frozen\t%s\n' "$receipt_count"
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_school_anatomy_exact\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$actual_mismatches"
printf 'api_reply_references\t%s/%s\n' "$actual_references" "$api_turns"
printf 'school_questions\t%s\n' "$actual_questions"
printf 'visible_question_turns\t%s\n' "$actual_visible_questions"
printf 'final_pending\t%s\n' "$final_pending"
printf 'final_deferred\t%s\n' "$final_deferred_word"
printf 'result\thuman-opening-removes-synthetic-room-but-api-care-still-shapes-the-life\n'
printf 'A.148 human-first ordinary life: %s\n' "$OUT"
