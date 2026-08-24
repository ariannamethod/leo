#!/usr/bin/env bash
# A.122: paired A.121 whole-turn veto and bounded answer-followup candidate.
set -Eeuo pipefail

trap 'rc=$?; printf "answer-followup matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-answer-followup-$STAMP}"
CONTROL="$OUT/control"
CANDIDATE="$OUT/candidate"
VERDICT="$OUT/verdict.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

LEO_ANSWER_FOLLOWUP=0 LEO_ANSWER_FOLLOWUP_EXPECT=a121 \
    "$ROOT/scripts/answer_followup_anatomy.sh" "$CONTROL" > "$OUT/control.out"
LEO_ANSWER_FOLLOWUP=1 LEO_ANSWER_FOLLOWUP_EXPECT=a122 \
    "$ROOT/scripts/answer_followup_anatomy.sh" "$CANDIDATE" > "$OUT/candidate.out"

cmp -s "$CONTROL/anatomy.tsv" "$CANDIDATE/anatomy.tsv"
cmp -s "$CONTROL/natural.tsv" "$CANDIDATE/natural.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 10 { exit 2 }
    $4 != "none" { grounded++ }
    $5 != "unreferenced" { referenced++ }
    $9 != "none" || $10 != "unreferenced" { historical_leak++ }
    $1 ~ /^(question-shaped|counter-question|question-first|tail-names-target|comma-question|sensory-anaphora|delayed-anaphora)$/ {
        if ($4 != "none" || $5 != "unreferenced") exit 2
        refusals++
    }
    $1 == "negative-followup" {
        if ($4 != "none" || $5 != "explicit" || $7 != 1) exit 2
        negative++
    }
    END {
        if (NR != 16 || grounded != 7 || referenced != 8 ||
            historical_leak != 0 || refusals != 7 || negative != 1) exit 2
    }
' "$CANDIDATE/anatomy.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 11 || $8 != "true" || $9 != "true" ||
        $10 != "true" || $11 != "true" { exit 2 }
    { open += $6; rows++ }
    END { if (rows != 3 || open != 27) exit 2 }
' "$CANDIDATE/natural.tsv"

{
    printf 'metric\ta121_whole_turn_veto\ta122_bounded_answer\n'
    printf 'grounded_answer_followups\t0\t7\n'
    printf 'referenced_negative_followups\t0\t1\n'
    printf 'counterfeit_question_refusals\t7/7\t7/7\n'
    printf 'a121_exact_natural_lives\t3/3\t3/3\n'
    printf 'open_wonder_turns\t27\t27\n'
    printf 'result\tquestions-erase-prior-answers\tbounded-answers-survive-followups\n'
} > "$VERDICT"

cat "$VERDICT"
printf 'A.122 answer-followup matrix: %s\n' "$OUT"
