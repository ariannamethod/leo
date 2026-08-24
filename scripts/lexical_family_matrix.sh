#!/usr/bin/env bash
# A.120: paired A.119 surface-form control and witnessed-family candidate.
set -Eeuo pipefail

trap 'rc=$?; printf "lexical-family matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-lexical-family-$STAMP}"
CONTROL="$OUT/control"
CANDIDATE="$OUT/candidate"
VERDICT="$OUT/verdict.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

LEO_LEXICAL_FAMILY=0 LEO_LEXICAL_EXPECT=a119 \
    "$ROOT/scripts/lexical_family_anatomy.sh" "$CONTROL" > "$OUT/control.out"
LEO_LEXICAL_FAMILY=1 LEO_LEXICAL_EXPECT=a120 \
    "$ROOT/scripts/lexical_family_anatomy.sh" "$CANDIDATE" > "$OUT/candidate.out"

cmp -s "$CONTROL/anatomy.tsv" "$CANDIDATE/anatomy.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 11 || $1 != "life" || $8 != "a119_transcript_exact" ||
            $11 != "a120_state_exact") exit 2
        next
    }
    NF != 11 || $8 != "true" || $9 != "true" { exit 2 }
    { open += $6; rows++ }
    END { if (rows != 3 || open != 52) exit 2 }
' "$CONTROL/natural.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 11 || $10 != "true" || $11 != "true" { exit 2 }
    $1 == "home" {
        if ($6 != 20 || $7 != "beneath@5,beneath@11,beneath@18" ||
            $8 != "true" || $9 != "false") exit 2
        home++
    }
    $1 == "weather" {
        if ($6 != 14 || $7 != "smooth@11,smooth@16,smooth@18,smooth@20") exit 2
        weather++
    }
    $1 == "memory" {
        if ($6 != 1 || $7 != "fragile@24") exit 2
        memory++
    }
    $7 ~ /(^|,)(rainy|belonged|outdoors|calmer|respecting|neighbor|loss|bring)@/ { exit 2 }
    { open += $6; rows++ }
    END {
        if (rows != 3 || open != 35 || home != 1 || weather != 1 || memory != 1)
            exit 2
    }
' "$CANDIDATE/natural.tsv"

{
    printf 'metric\ta119_surface\ta120_family\n'
    printf 'expected_exact_lives\t3/3\t3/3\n'
    printf 'open_wonder_turns\t52\t35\n'
    printf 'witnessed_family_question_receipts\t6\t0\n'
    printf 'home_questions\tbeneath\tbeneath\n'
    printf 'weather_questions\trainy\tsmooth\n'
    printf 'memory_questions\toutdoors,belonged\tfragile\n'
    printf 'result\tsurface-forms-separated\twitnessed-families-refused\n'
} > "$VERDICT"

cat "$VERDICT"
printf 'A.120 lexical-family matrix: %s\n' "$OUT"
