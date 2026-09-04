#!/usr/bin/env bash
# A.144: replay the frozen second fresh ordinary life without API calls.
set -Eeuo pipefail

trap 'rc=$?; printf "second fresh ordinary life replay failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-second-fresh-ordinary-life-a144-replay-$STAMP}"
FROZEN="$ROOT/scripts/second_fresh_ordinary_life_a144_frozen.tsv"
PLAN="$ROOT/scripts/second_fresh_ordinary_life_a144_plan.tsv"
API_TURNS="$ROOT/scripts/second_fresh_ordinary_life_a144_api_turns.tsv"
ANATOMY="$ROOT/scripts/second_fresh_ordinary_life_a144_anatomy.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r life seed fixture plan_sha api_turns_sha anatomy_sha \
    api_turns completed store_false model prompts_sha transcript_sha state_sha \
    async_transcript_sha async_state_sha mismatches references open_stances \
    follow_stances answer_stances comfort_stances open questions \
    first_question_turn first_question_reply first_response_turn \
    first_response_prompt first_response_stance second_question_turn \
    second_question_reply final_pending final_primary final_alternate \
    final_pending_turns final_wonders finished_heard finished_learned \
    finished_resolved yeah_heard yeah_learned yeah_resolved \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
PROMPTS="$ROOT/$fixture"

[ "$life" = ordinary ] && [ "$seed" = 542 ]
[ "$api_turns" = 24 ] && [ "$completed" = 24 ] && [ "$store_false" = 24 ]
[ "$model" = gpt-5.6-luna ]
[ "$first_question_turn" = 4 ] && [ "$first_question_reply" = 'Finished?' ]
[ "$first_response_turn" = 5 ] && [ "$first_response_stance" = answer ]
[ "$second_question_turn" = 6 ] && [ "$second_question_reply" = 'Yeah?' ]

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$API_TURNS")" = "$api_turns_sha" ]
[ "$(sha256_file "$ANATOMY")" = "$anatomy_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

for turns in 3 4 5 6; do
    sed -n "1,${turns}p" "$PROMPTS" > "$OUT/turn${turns}.prompts"
    LEO_NATURAL_REPLAY_FILE="$OUT/turn${turns}.prompts" \
        LEO_NATURAL_PHASE=A.144 \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=replay \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
        LEO_NATURAL_OPENING='Replay the frozen second ordinary life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/turn${turns}" \
        > "$OUT/turn${turns}.out"
done

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.144 \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Replay the frozen second ordinary life.' \
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

cc "$ROOT/scripts/second_fresh_ordinary_life_a144_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/second-fresh-ordinary-life-fixture" -lpthread
"$OUT/second-fresh-ordinary-life-fixture" \
    "$OUT/turn3/state/leo.state" \
    "$OUT/turn4/state/leo.state" \
    "$OUT/turn5/state/leo.state" \
    "$OUT/turn6/state/leo.state" \
    "$OUT/lives/replay/state/leo.state" \
    "$OUT/lives/async-a/state/leo.state" > "$OUT/anatomy.tsv"
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
count_stance() {
    awk -F '\t' -v stance="$1" \
        'NR > 1 && $3 == stance { n++ } END { print n + 0 }' "$API_TURNS"
}
actual_references="$(awk -F '\t' 'NR > 1 && $4 == "true" { n++ } END { print n + 0 }' \
    "$API_TURNS")"
[ "$actual_questions" = "$questions" ] && [ "$actual_open" = "$open" ]
[ "$actual_references" = "$references" ]
[ "$(count_stance open)" = "$open_stances" ]
[ "$(count_stance follow)" = "$follow_stances" ]
[ "$(count_stance answer)" = "$answer_stances" ]
[ "$(count_stance comfort)" = "$comfort_stances" ]
[ "$(awk -F '\t' -v turn="$first_response_turn" \
       '$1 == turn { print $2 }' "$API_TURNS")" = "$first_response_prompt" ]

awk -F '\t' -v pending="$final_pending" -v primary="$final_primary" \
    -v alternate="$final_alternate" -v turns="$final_pending_turns" \
    -v wonders="$final_wonders" -v finished_heard="$finished_heard" \
    -v finished_learned="$finished_learned" \
    -v finished_resolved="$finished_resolved" -v yeah_heard="$yeah_heard" \
    -v yeah_learned="$yeah_learned" -v yeah_resolved="$yeah_resolved" '
    $1 == "turn24" && $2 == "finished" {
        if ($3 != finished_heard || $4 != finished_learned ||
            $11 != finished_resolved || $15 != pending ||
            $16 != primary || $17 != alternate || $18 != turns ||
            $19 != wonders) exit 2
        finished++
    }
    $1 == "turn24" && $2 == "yeah" {
        if ($3 != yeah_heard || $4 != yeah_learned ||
            $11 != yeah_resolved || $15 != pending ||
            $16 != primary || $17 != alternate || $18 != turns ||
            $19 != wonders) exit 2
        yeah++
    }
    END { if (finished != 1 || yeah != 1) exit 2 }
' "$OUT/anatomy.tsv"

printf 'metric\tvalue\n'
printf 'sync_replay_exact\ttrue\n'
printf 'async_reproducible\ttrue\n'
printf 'sync_async_reply_mismatches\t%s\n' "$actual_mismatches"
printf 'api_turns_frozen\t%s\n' "$api_turns"
printf 'api_reply_references\t%s\n' "$actual_references"
printf 'school_questions\t%s\n' "$actual_questions"
printf 'first_response_stance\t%s\n' "$first_response_stance"
printf 'final_pending\t%s\n' "$final_pending"
printf 'final_pending_turns\t%s\n' "$final_pending_turns"
printf 'result\tsecond-fresh-ordinary-life-exposes-discourse-wonder\n'
printf 'A.144 second fresh ordinary life replay: %s\n' "$OUT"
