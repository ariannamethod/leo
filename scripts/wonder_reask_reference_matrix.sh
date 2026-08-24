#!/usr/bin/env bash
# A.123: paired A.122 single-glyph recall and bounded reask-reference candidate.
set -Eeuo pipefail

trap 'rc=$?; printf "wonder-reask-reference matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-wonder-reask-reference-$STAMP}"
CONTROL="$OUT/control"
CANDIDATE="$OUT/candidate"
VERDICT="$OUT/verdict.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

LEO_WONDER_REASK_REFERENCE=0 LEO_WONDER_REASK_REFERENCE_EXPECT=a122 \
    "$ROOT/scripts/wonder_reask_reference_anatomy.sh" "$CONTROL" > "$OUT/control.out"
LEO_WONDER_REASK_REFERENCE=1 LEO_WONDER_REASK_REFERENCE_EXPECT=a123 \
    "$ROOT/scripts/wonder_reask_reference_anatomy.sh" "$CANDIDATE" > "$OUT/candidate.out"

cmp -s "$CONTROL/anatomy.tsv" "$CANDIDATE/anatomy.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 6 || $3 != $4 || $5 != $6 { exit 2 }
    $3 == 1 { bounded++ }
    $5 == 1 { historical++ }
    $1 ~ /^(plain-hypothesis|other-subject-question|nominal-subject-question|prior-clause-only|both-unreferenced|sensory-anaphora|what-about)$/ {
        if ($3 != 0 || $4 != 0 || $5 != 1 || $6 != 1) exit 2
        refusals++
    }
    $1 == "unrelated" && ($3 != 0 || $4 != 0 || $5 != 0 || $6 != 0) { exit 2 }
    END {
        if (NR != 14 || bounded != 5 || historical != 12 || refusals != 7) exit 2
    }
' "$CANDIDATE/anatomy.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 11 || $8 != "true" || $9 != "true" { exit 2 }
    { open += $6; rows++ }
    $1 == "home" && $7 != "toy@13" { exit 2 }
    $1 == "weather" && $7 != "smooth@11,smooth@16,smooth@18,smooth@20" { exit 2 }
    $1 == "memory" && $7 != "fragile@24" { exit 2 }
    END { if (rows != 3 || open != 27) exit 2 }
' "$CONTROL/natural.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 11 || $10 != "true" || $11 != "true" { exit 2 }
    $8 == "true" { a122_transcript++ }
    $9 == "true" { a122_state++ }
    { open += $6; rows++ }
    $1 == "home" && $7 != "toy@13" { exit 2 }
    $1 == "weather" && $7 != "smooth@11" { exit 2 }
    $1 == "memory" && $7 != "fragile@24" { exit 2 }
    END {
        if (rows != 3 || open != 27 ||
            a122_transcript != 2 || a122_state != 1) exit 2
    }
' "$CANDIDATE/natural.tsv"

{
    printf 'metric\ta122_single_glyph\ta123_bounded_reference\n'
    printf 'named_or_anaphoric_invitations\t5/5\t5/5\n'
    printf 'counterfeit_reference_refusals\t0/7\t7/7\n'
    printf 'natural_question_receipts\t6\t3\n'
    printf 'accidental_hypothesis_reasks\t3\t0\n'
    printf 'a122_exact_transcript_lives\t3/3\t2/3\n'
    printf 'a122_exact_state_lives\t3/3\t1/3\n'
    printf 'open_wonder_turns\t27\t27\n'
    printf 'result\tguessed-glyphs-recall-unnamed-wonder\treference-bounds-reask\n'
} > "$VERDICT"

cat "$VERDICT"
printf 'A.123 wonder-reask-reference matrix: %s\n' "$OUT"
