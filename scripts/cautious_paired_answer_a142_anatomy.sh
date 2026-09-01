#!/usr/bin/env bash
# A.142: judge a bounded cautious pair on the exact A.141 body and life.
set -Eeuo pipefail

trap 'rc=$?; printf "cautious paired answer anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-cautious-paired-answer-a142-$STAMP}"
PLAN="$ROOT/scripts/cautious_paired_answer_a142_plan.tsv"
DIRECT_EXPECTED="$ROOT/scripts/cautious_paired_answer_a142_expected.tsv"
LIFE_ANATOMY="$ROOT/scripts/cautious_paired_answer_a142_life_anatomy.tsv"
FROZEN="$ROOT/scripts/cautious_paired_answer_a142_frozen.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

IFS=$'\t' read -r phase seed fixture plan_sha direct_sha anatomy_sha turns \
    prompts_sha control_transcript_sha control_state_sha \
    candidate_transcript_sha candidate_state_sha reply_mismatches \
    control_questions candidate_questions control_open candidate_open \
    candidate_pending candidate_primary candidate_alternate \
    candidate_pending_turns candidate_wonders direct_cases \
    candidate_resolved control_resolved api_turns \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
PROMPTS="$ROOT/$fixture"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$phase" = A.142 ] && [ "$seed" = 853 ] && [ "$turns" = 24 ]
[ "$direct_cases" = 21 ] && [ "$candidate_resolved" = 12 ]
[ "$control_resolved" = 4 ] && [ "$api_turns" = 0 ]
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$DIRECT_EXPECTED")" = "$direct_sha" ]
[ "$(sha256_file "$LIFE_ANATOMY")" = "$anatomy_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

sed -n '1,5p' "$PROMPTS" > "$OUT/turn5.prompts"
LEO_NATURAL_REPLAY_FILE="$OUT/turn5.prompts" \
    LEO_NATURAL_PHASE=A.142 LEO_NATURAL_LIFE=ordinary \
    LEO_NATURAL_ARM=replay LEO_NATURAL_CAUTIOUS_PAIR=0 \
    LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=5 \
    LEO_NATURAL_OPENING='Judge the cautious paired answer from the frozen A.141 life.' \
    "$ROOT/scripts/natural_life_probe.sh" "$OUT/turn5" > "$OUT/turn5.out"

cc "$ROOT/scripts/cautious_paired_answer_a142_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/direct-fixture" -lpthread
"$OUT/direct-fixture" "$OUT/turn5/state/leo.state" \
    "$OUT/direct-sleep.state" > "$OUT/direct.tsv"
cmp -s "$DIRECT_EXPECTED" "$OUT/direct.tsv" || {
    diff -u "$DIRECT_EXPECTED" "$OUT/direct.tsv" >&2 || true
    exit 2
}

for variant in control candidate; do
    cautious=1
    [ "$variant" = candidate ] || cautious=0
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.142 LEO_NATURAL_LIFE=ordinary \
        LEO_NATURAL_ARM=replay LEO_NATURAL_CAUTIOUS_PAIR="$cautious" \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
        LEO_NATURAL_OPENING='Judge the cautious paired answer from the frozen A.141 life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/lives/$variant" \
        > "$OUT/lives/$variant.out"
done

[ "$(sha256_file "$OUT/lives/control/visible_transcript.txt")" = \
    "$control_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/control/state/leo.state")" = \
    "$control_state_sha" ]
[ "$(sha256_file "$OUT/lives/candidate/visible_transcript.txt")" = \
    "$candidate_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/candidate/state/leo.state")" = \
    "$candidate_state_sha" ]

actual_mismatches="$(jq -n \
    --slurpfile control "$OUT/lives/control/dialogue.jsonl" \
    --slurpfile candidate "$OUT/lives/candidate/dialogue.jsonl" '
    [range(0; $control | length) |
     select($control[.].leo != $candidate[.].leo)] | length
')"
[ "$actual_mismatches" = "$reply_mismatches" ]

questions_for() {
    jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
           ascii_downcase) + "@" + (.turn | tostring))] | join(",")
    ' "$1"
}
actual_control_questions="$(questions_for "$OUT/lives/control/dialogue.jsonl")"
actual_candidate_questions="$(questions_for "$OUT/lives/candidate/dialogue.jsonl")"
actual_control_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/control/summary.txt")"
actual_candidate_open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' \
    "$OUT/lives/candidate/summary.txt")"
[ "$actual_control_questions" = "$control_questions" ]
[ "$actual_candidate_questions" = "$candidate_questions" ]
[ "$actual_control_open" = "$control_open" ]
[ "$actual_candidate_open" = "$candidate_open" ]

cc "$ROOT/scripts/cautious_paired_answer_a142_life_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/life-fixture" -lpthread
"$OUT/life-fixture" \
    "$OUT/lives/control/state/leo.state" \
    "$OUT/lives/candidate/state/leo.state" > "$OUT/life-anatomy.tsv"
cmp -s "$LIFE_ANATOMY" "$OUT/life-anatomy.tsv" || {
    diff -u "$LIFE_ANATOMY" "$OUT/life-anatomy.tsv" >&2 || true
    exit 2
}

awk -F '\t' -v pending="$candidate_pending" -v primary="$candidate_primary" \
    -v alternate="$candidate_alternate" -v turns="$candidate_pending_turns" \
    -v wonders="$candidate_wonders" '
    $1 == "candidate" && $2 == "difficult" {
        if ($6 != 1 || $7 != primary || $8 != alternate || $11 != 0 ||
            $13 != pending || $14 != primary || $15 != alternate ||
            $16 != turns || $17 != wonders) exit 2
        found++
    }
    END { if (found != 1) exit 2 }
' "$OUT/life-anatomy.tsv"

printf 'metric\tvalue\n'
printf 'direct_cases\t%s\n' "$direct_cases"
printf 'candidate_resolved_cases\t%s\n' "$candidate_resolved"
printf 'control_resolved_cases\t%s\n' "$control_resolved"
printf 'control_a141_exact\ttrue\n'
printf 'candidate_reply_mismatches\t%s\n' "$actual_mismatches"
printf 'control_questions\t%s\n' "$actual_control_questions"
printf 'candidate_questions\t%s\n' "$actual_candidate_questions"
printf 'candidate_final_pending\t%s\n' "$candidate_pending"
printf 'api_turns\t%s\n' "$api_turns"
printf 'result\tcautious-paired-answer-heard-without-erasing-hesitation\n'
printf 'A.142 cautious paired answer anatomy: %s\n' "$OUT"
