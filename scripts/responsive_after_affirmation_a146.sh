#!/usr/bin/env bash
# A.146: give the exact A.145 candidate body a fresh visible-only continuation.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive after affirmation failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-after-affirmation-a146-$STAMP}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
PLAN="$ROOT/scripts/responsive_after_affirmation_a146_plan.tsv"
FROZEN="$ROOT/scripts/responsive_after_affirmation_a146_frozen.tsv"
PREFIX="$ROOT/scripts/fixtures/affirmation_role_a145_prefix.txt"
PREFIX_EXPECTED="$ROOT/scripts/responsive_after_affirmation_a146_prefix_expected.jsonl"
FROZEN_PROMPTS="$ROOT/scripts/fixtures/responsive_after_affirmation_a146_ordinary.txt"
API_TURNS="$ROOT/scripts/responsive_after_affirmation_a146_api_turns.tsv"
ANATOMY="$ROOT/scripts/responsive_after_affirmation_a146_anatomy.tsv"
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
plan_value() { awk -F '\t' -v key="$1" '$1 == key { print $2 }' "$PLAN"; }

if [ ! -f "$API/dialogue.jsonl" ]; then
    LEO_NATURAL_REPLAY_FILE="$PREFIX" \
        LEO_NATURAL_PHASE=A.146 \
        LEO_NATURAL_QUESTION=responsive-after-affirmation \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=542 LEO_NATURAL_TURNS=6 \
        LEO_NATURAL_OPENING='Continue the exact visible ordinary life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$API" \
        > "$OUT/lives/prefix.out"
fi

jq -c '{turn, human, leo}' "$API/dialogue.jsonl" | sed -n '1,6p' \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$PREFIX_EXPECTED" "$OUT/prefix.actual.jsonl" || {
    printf 'post-affirmation six-turn prefix did not reproduce exactly\n' >&2
    diff -u "$PREFIX_EXPECTED" "$OUT/prefix.actual.jsonl" >&2 || true
    exit 1
}
completed="$(wc -l < "$API/dialogue.jsonl" | tr -d ' ')"
if [ "$completed" -eq 6 ]; then
    [ "$(sha256_file "$API/visible_transcript.txt")" = \
        "$(plan_value source_transcript_sha256)" ]
    [ "$(sha256_file "$API/state/leo.state")" = \
        "$(plan_value source_state_sha256)" ]
fi
if [ "$completed" -ge 6 ] && [ "$completed" -lt 24 ]; then
    OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
        LEO_NATURAL_PHASE=A.146 \
        LEO_NATURAL_QUESTION=responsive-after-affirmation \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=542 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Continue the exact visible ordinary life.' \
        LEO_NATURAL_RESUME=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$API" \
        > "$OUT/lives/api.out"
elif [ "$completed" -ne 24 ]; then
    printf 'unexpected completed turn count: %s\n' "$completed" >&2
    exit 2
fi

cmp -s "$FROZEN_PROMPTS" "$API/prompts.txt"
printf 'turn\tutterance\tstance\treply_reference\tmodel\n' \
    > "$OUT/api-turns.actual.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" }
    NR > 1 && $3 >= 7 { print $3, $5, $6, $7, $8 }
' "$API/sessions.tsv" >> "$OUT/api-turns.actual.tsv"
cmp -s "$API_TURNS" "$OUT/api-turns.actual.tsv"

receipt_count=0
for response in "$API"/api/turn-*.response.json; do
    jq -e '.status == "completed" and .store == false and
           (.model | type) == "string"' "$response" >/dev/null
    receipt_count=$((receipt_count + 1))
done
[ "$receipt_count" -eq 18 ]

jq -e '.source == "frozen-prefix-then-responses-api-visible-transcript" and
       .replay_prefix_turns == 6 and .api_turns == 18 and
       .api_store == false and .transcript_visible_to_interlocutor == true and
       .diagnostics_visible_to_interlocutor == false and
       .school_affirmation_role == true and
       .school_cautious_pair == true' "$API/manifest.json" >/dev/null

for turns in 6 7; do
    sed -n "1,${turns}p" "$API/prompts.txt" > "$OUT/points/turn${turns}.prompts"
    destination="$OUT/points/turn${turns}"
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$OUT/points/turn${turns}.prompts" \
            LEO_NATURAL_PHASE=A.146 \
            LEO_NATURAL_QUESTION=responsive-after-affirmation \
            LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=replay \
            LEO_NATURAL_SEED=542 LEO_NATURAL_TURNS="$turns" \
            LEO_NATURAL_OPENING='Replay the frozen responsive post-affirmation life.' \
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
            LEO_NATURAL_PHASE=A.146 \
            LEO_NATURAL_QUESTION=responsive-after-affirmation \
            LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
            LEO_NATURAL_SEED=542 LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OPENING='Replay the frozen responsive post-affirmation life.' \
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

questions_for() {
    jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
           ascii_downcase) + "@" + (.turn | tostring))] | join(",")
    ' "$1"
}
continuation_questions="$(jq -sr '
    [.[] | select(.turn >= 7 and (.leo | test("^[[:alpha:]]+\\?"))) |
     ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
       ascii_downcase) + "@" + (.turn | tostring))] |
    if length == 0 then "none" else join(",") end
' "$OUT/lives/replay/dialogue.jsonl")"
reply_mismatches="$(jq -n \
    --slurpfile sync "$OUT/lives/replay/dialogue.jsonl" \
    --slurpfile async "$OUT/lives/async-a/dialogue.jsonl" '
    [range(0; $sync | length) |
     select($sync[.].leo != $async[.].leo)] | length
')"
references="$(awk -F '\t' 'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' "$API_TURNS")"
follow="$(awk -F '\t' 'NR > 1 && $3 == "follow" { n++ } END { print n + 0 }' "$API_TURNS")"
clarify="$(awk -F '\t' 'NR > 1 && $3 == "clarify" { n++ } END { print n + 0 }' "$API_TURNS")"
comfort="$(awk -F '\t' 'NR > 1 && $3 == "comfort" { n++ } END { print n + 0 }' "$API_TURNS")"
answers="$(awk -F '\t' 'NR > 1 && $3 == "answer" { n++ } END { print n + 0 }' "$API_TURNS")"
open_turns="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' "$OUT/lives/replay/summary.txt")"

IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ \
    frozen_transcript_sha frozen_state_sha frozen_async_transcript_sha \
    frozen_async_state_sha frozen_mismatches frozen_references \
    frozen_follow frozen_clarify frozen_comfort frozen_answers \
    frozen_questions frozen_continuation_questions frozen_open_turns \
    _ _ _ _ _ _ _ _ _ _ _ _ _ _ \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
[ "$(sha256_file "$API/visible_transcript.txt")" = "$frozen_transcript_sha" ]
[ "$(sha256_file "$API/state/leo.state")" = "$frozen_state_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" = "$frozen_async_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/async-a/state/leo.state")" = "$frozen_async_state_sha" ]
[ "$(questions_for "$OUT/lives/replay/dialogue.jsonl")" = "$frozen_questions" ]
[ "$continuation_questions" = "$frozen_continuation_questions" ]
[ "$reply_mismatches" = "$frozen_mismatches" ]
[ "$references" = "$frozen_references" ]
[ "$follow" = "$frozen_follow" ] && [ "$clarify" = "$frozen_clarify" ]
[ "$comfort" = "$frozen_comfort" ] && [ "$answers" = "$frozen_answers" ]
[ "$open_turns" = "$frozen_open_turns" ]

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_school_anatomy_exact\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$reply_mismatches"
printf 'api_turns_frozen\t%s\n' "$receipt_count"
printf 'api_reply_references\t%s\n' "$references"
printf 'school_questions\t%s\n' "$frozen_questions"
printf 'continuation_questions\t%s\n' "$continuation_questions"
printf 'final_pending\tfinished\n'
printf 'final_deferred\tsomehow\n'
printf 'result\tpost-affirmation-mouth-continues-without-shifted-interruption\n'
printf 'A.146 responsive after affirmation: %s\n' "$OUT"
