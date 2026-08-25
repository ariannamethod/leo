#!/usr/bin/env bash
# A.125: 2x2 replay of offered-answer expansion and follow-up question scope.
set -Eeuo pipefail

trap 'rc=$?; printf "natural-answer-form matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-answer-form-$STAMP}"
CASES="${LEO_NATURAL_ANSWER_FORM_CASES:-$ROOT/scripts/natural_life_second_generation_frozen.tsv}"
EXPECTED="${LEO_NATURAL_ANSWER_FORM_EXPECTED:-$ROOT/scripts/natural_answer_form_expected.tsv}"
PLAN_ONLY="${LEO_NATURAL_ANSWER_FORM_PLAN_ONLY:-0}"

[ -s "$CASES" ] || { printf 'missing A.124 frozen cases: %s\n' "$CASES" >&2; exit 2; }
[ -s "$EXPECTED" ] || { printf 'missing A.125 frozen factorial: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_NATURAL_ANSWER_FORM_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

{
    printf 'arm\toffered_answer_expansion\tfollowup_question_scope\n'
    printf 'control\t0\t0\n'
    printf 'expansion-only\t1\t0\n'
    printf 'scope-only\t0\t1\n'
    printf 'candidate\t1\t1\n'
} > "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.125 natural-answer-form plan: %s\n' "$OUT"
    exit 0
fi

"$ROOT/scripts/natural_answer_form_anatomy.sh" "$OUT/anatomy" > "$OUT/anatomy.out"

printf 'arm\tlife\tseed\toffered_answer_expansion\tfollowup_question_scope\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta124_transcript_exact\ta124_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm expansion scope; do
    [ "$arm" != arm ] || continue
    while IFS=$'\t' read -r life seed fixture prompts_sha a124_transcript a124_state async_transcript async_state mismatches; do
        [ "$life" != life ] || continue
        fixture_path="$ROOT/$fixture"
        [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
        [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
            printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
        }
        destination="$OUT/lives/$arm/$life"
        LEO_NATURAL_REPLAY_FILE="$fixture_path" \
            LEO_NATURAL_PHASE=A.125 LEO_NATURAL_LIFE="$life" \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OFFERED_ANSWER_EXPANSION="$expansion" \
            LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE="$scope" \
            LEO_NATURAL_TWO_GLYPH_LEARNING=0 \
            LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=0 \
            LEO_NATURAL_NEGATIVE_FAMILY=0 \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/lives/$arm-$life.out"
        transcript_sha="$(shasum -a 256 "$destination/visible_transcript.txt" | awk '{print $1}')"
        state_sha="$(shasum -a 256 "$destination/state/leo.state" | awk '{print $1}')"
        open="$(awk -F '\t' '$1 == "wonder_open_turns" {print $2}' "$destination/summary.txt")"
        questions="$(jq -sr '
            [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
             ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
              "@" + (.turn | tostring))] | join(",")
        ' "$destination/dialogue.jsonl")"
        transcript_exact=false; state_exact=false
        [ "$transcript_sha" != "$a124_transcript" ] || transcript_exact=true
        [ "$state_sha" != "$a124_state" ] || state_exact=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$arm" "$life" "$seed" "$expansion" "$scope" \
            "$transcript_sha" "$state_sha" "$open" "$questions" \
            "$transcript_exact" "$state_exact" >> "$OUT/natural.tsv"
    done < "$CASES"
done < "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 11 { exit 2 }
    $1 == "control" { rows++; exact += ($10 == "true" && $11 == "true") }
    END { if (rows != 3 || exact != 3) exit 2 }
' "$OUT/natural.tsv"

if ! cmp -s "$EXPECTED" "$OUT/natural.tsv"; then
    diff -u "$EXPECTED" "$OUT/natural.tsv" >&2 || true
    printf 'A.125 frozen factorial drift\n' >&2
    exit 2
fi

cat "$OUT/natural.tsv"
printf 'result\tnatural-answer-form-factorial-exact\n'
printf 'A.125 natural-answer-form matrix: %s\n' "$OUT"
