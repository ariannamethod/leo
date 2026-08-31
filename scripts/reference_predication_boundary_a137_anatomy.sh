#!/usr/bin/env bash
# A.137: separate explicit Wonder reference from positive meaning predication.
set -Eeuo pipefail

trap 'rc=$?; printf "reference-predication anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-reference-predication-boundary-a137-$STAMP}"
EXPECTED="$ROOT/scripts/reference_predication_boundary_a137_expected.tsv"
NATURAL_EXPECTED="$ROOT/scripts/reference_predication_boundary_a137_natural.tsv"
FROZEN="$ROOT/scripts/reference_predication_boundary_a137_frozen.tsv"
A136_FROZEN="$ROOT/scripts/responsive_difficult_return_a136_frozen.tsv"
PROMPTS="$ROOT/scripts/fixtures/responsive_difficult_return_a136_meal.txt"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/reference_predication_boundary_a137_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/reference-predication-fixture" -lpthread
"$OUT/reference-predication-fixture" > "$OUT/direct.tsv"
cmp -s "$EXPECTED" "$OUT/direct.tsv"

for law in candidate control; do
    toggle=1
    [ "$law" = candidate ] || toggle=0
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.137 \
        LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=replay \
        LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=35 \
        LEO_NATURAL_OPENING='Replay A.136 under the A.137 reference-predication court.' \
        LEO_NATURAL_REFERENCE_PREDICATION="$toggle" \
        LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/$law" \
        > "$OUT/$law.out"
done

jq -e '.school_reference_predication == true' \
    "$OUT/candidate/manifest.json" >/dev/null
jq -e '.school_reference_predication == false' \
    "$OUT/control/manifest.json" >/dev/null

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
IFS=$'\t' read -r phase fixture candidate_transcript candidate_state \
    control_transcript control_state mismatches exact_through candidate_open \
    control_open questions < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
[ "$phase" = A.137 ] && [ "$fixture" = scripts/fixtures/responsive_difficult_return_a136_meal.txt ]
[ "$(sha256_file "$OUT/candidate/visible_transcript.txt")" = "$candidate_transcript" ]
[ "$(sha256_file "$OUT/candidate/state/leo.state")" = "$candidate_state" ]
[ "$(sha256_file "$OUT/control/visible_transcript.txt")" = "$control_transcript" ]
[ "$(sha256_file "$OUT/control/state/leo.state")" = "$control_state" ]

a136_transcript="$(awk -F '\t' 'NR == 2 { print $8 }' "$A136_FROZEN")"
a136_state="$(awk -F '\t' 'NR == 2 { print $9 }' "$A136_FROZEN")"
[ "$control_transcript" = "$a136_transcript" ]
[ "$control_state" = "$a136_state" ]

cmp -s \
    <(jq -r --argjson end "$exact_through" 'select(.turn <= $end) | .leo' "$OUT/candidate/dialogue.jsonl") \
    <(jq -r --argjson end "$exact_through" 'select(.turn <= $end) | .leo' "$OUT/control/dialogue.jsonl")

actual_mismatches="$(jq -n \
    --slurpfile left "$OUT/candidate/dialogue.jsonl" \
    --slurpfile right "$OUT/control/dialogue.jsonl" '
    [$left, $right] as [$l, $r] |
    [range(0; $l | length) | select($l[.].leo != $r[.].leo)] | length')"
[ "$actual_mismatches" = "$mismatches" ]

for law in candidate control; do
    actual_questions="$(jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
          "@" + (.turn | tostring))] | join(",")
    ' "$OUT/$law/dialogue.jsonl")"
    [ "$actual_questions" = "$questions" ]
done
[ "$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' "$OUT/candidate/summary.txt")" = "$candidate_open" ]
[ "$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' "$OUT/control/summary.txt")" = "$control_open" ]

cc "$ROOT/scripts/reference_predication_boundary_a137_natural_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/reference-predication-natural-fixture" -lpthread
"$OUT/reference-predication-natural-fixture" \
    "$OUT/candidate/state/leo.state" \
    "$OUT/control/state/leo.state" > "$OUT/natural.tsv"
cmp -s "$NATURAL_EXPECTED" "$OUT/natural.tsv"

printf 'metric\tvalue\n'
printf 'direct_cases\t15\n'
printf 'false_lessons_refused\t4\n'
printf 'neutral_references_preserved\t2\n'
printf 'positive_answer_forms_preserved\t7\n'
printf 'negative_forms_preserved\t2\n'
printf 'historical_a136_control_exact\ttrue\n'
printf 'candidate_control_reply_mismatches\t%s\n' "$mismatches"
printf 'reply_exact_through_turn\t%s\n' "$exact_through"
printf 'candidate_open_wonder_turns\t%s\n' "$candidate_open"
printf 'control_open_wonder_turns\t%s\n' "$control_open"
printf 'school_questions\t%s\n' "$questions"
printf 'result\treference-is-not-predication\n'
printf 'A.137 reference-predication anatomy: %s\n' "$OUT"
