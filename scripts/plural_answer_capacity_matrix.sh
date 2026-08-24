#!/usr/bin/env bash
# A.126: replay the A.125 candidate with and without tied-glyph abstention.
set -Eeuo pipefail

trap 'rc=$?; printf "plural-answer-capacity matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-plural-answer-capacity-$STAMP}"
CASES="${LEO_PLURAL_ANSWER_CAPACITY_CASES:-$ROOT/scripts/natural_life_second_generation_frozen.tsv}"
A125="${LEO_PLURAL_ANSWER_CAPACITY_A125:-$ROOT/scripts/natural_answer_form_expected.tsv}"
EXPECTED="${LEO_PLURAL_ANSWER_CAPACITY_EXPECTED:-$ROOT/scripts/plural_answer_capacity_expected.tsv}"
PLAN_ONLY="${LEO_PLURAL_ANSWER_CAPACITY_PLAN_ONLY:-0}"

[ -s "$CASES" ] || { printf 'missing A.124 frozen cases: %s\n' "$CASES" >&2; exit 2; }
[ -s "$A125" ] || { printf 'missing A.125 frozen factorial: %s\n' "$A125" >&2; exit 2; }
[ -s "$EXPECTED" ] || { printf 'missing A.126 frozen replay: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_PLURAL_ANSWER_CAPACITY_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

{
    printf 'arm\tunique_answer_dominance\n'
    printf 'control\t0\n'
    printf 'candidate\t1\n'
} > "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.126 plural-answer-capacity plan: %s\n' "$OUT"
    exit 0
fi

"$ROOT/scripts/plural_answer_capacity_anatomy.sh" "$OUT/anatomy" > "$OUT/anatomy.out"

printf 'arm\tlife\tseed\tunique_answer_dominance\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta125_transcript_exact\ta125_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm unique; do
    [ "$arm" != arm ] || continue
    while IFS=$'\t' read -r life seed fixture prompts_sha _rest; do
        [ "$life" != life ] || continue
        fixture_path="$ROOT/$fixture"
        [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
        [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
            printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
        }
        a125_row="$(awk -F '\t' -v life="$life" '$1 == "candidate" && $2 == life {print; found++} END {if (found != 1) exit 2}' "$A125")"
        IFS=$'\t' read -r _a125_arm _a125_life _a125_seed _a125_expansion _a125_scope a125_transcript a125_state _a125_open _a125_questions _a124_tx _a124_state <<< "$a125_row"
        [ "$seed" = "$_a125_seed" ] || { printf 'A.125 seed drift: %s\n' "$life" >&2; exit 2; }

        destination="$OUT/lives/$arm/$life"
        LEO_NATURAL_REPLAY_FILE="$fixture_path" \
            LEO_NATURAL_PHASE=A.126 LEO_NATURAL_LIFE="$life" \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OFFERED_ANSWER_EXPANSION=1 \
            LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=1 \
            LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE="$unique" \
            LEO_NATURAL_TWO_GLYPH_LEARNING=0 \
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
        [ "$transcript_sha" != "$a125_transcript" ] || transcript_exact=true
        [ "$state_sha" != "$a125_state" ] || state_exact=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$arm" "$life" "$seed" "$unique" \
            "$transcript_sha" "$state_sha" "$open" "$questions" \
            "$transcript_exact" "$state_exact" >> "$OUT/natural.tsv"
    done < "$CASES"
done < "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 10 { exit 2 }
    $1 == "control" { rows++; exact += ($9 == "true" && $10 == "true") }
    END { if (rows != 3 || exact != 3) exit 2 }
' "$OUT/natural.tsv"

cmp -s "$EXPECTED" "$OUT/natural.tsv" || {
    diff -u "$EXPECTED" "$OUT/natural.tsv" >&2 || true
    printf 'A.126 frozen natural replay drift\n' >&2
    exit 2
}

cat "$OUT/natural.tsv"
printf 'result\tplural-answer-capacity-exact\n'
printf 'A.126 plural-answer-capacity matrix: %s\n' "$OUT"
