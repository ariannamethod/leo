#!/usr/bin/env bash
# A.121: paired A.120 unknown-word control and exact lexical-role candidate.
set -Eeuo pipefail

trap 'rc=$?; printf "lexical-role matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-lexical-role-$STAMP}"
CONTROL="$OUT/control"
CANDIDATE="$OUT/candidate"
VERDICT="$OUT/verdict.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

LEO_LEXICAL_ROLE=0 LEO_LEXICAL_ROLE_EXPECT=a120 \
    "$ROOT/scripts/lexical_role_anatomy.sh" "$CONTROL" > "$OUT/control.out"
LEO_LEXICAL_ROLE=1 LEO_LEXICAL_ROLE_EXPECT=a121 \
    "$ROOT/scripts/lexical_role_anatomy.sh" "$CANDIDATE" > "$OUT/candidate.out"

cmp -s "$CONTROL/anatomy.tsv" "$CANDIDATE/anatomy.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 11 || $1 != "life" || $8 != "a120_transcript_exact" ||
            $11 != "a121_state_exact") exit 2
        next
    }
    NF != 11 || $8 != "true" || $9 != "true" { exit 2 }
    { open += $6; rows++ }
    END { if (rows != 3 || open != 35) exit 2 }
' "$CONTROL/natural.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 11 || $10 != "true" || $11 != "true" { exit 2 }
    $1 == "home" {
        if ($6 != 12 || $7 != "toy@13" || $7 ~ /(^|,)(beneath|nearby|nor)@/)
            exit 2
        home++
    }
    $1 == "weather" {
        if ($6 != 14 || $7 != "smooth@11,smooth@16,smooth@18,smooth@20" ||
            $8 != "true" || $9 != "true") exit 2
        unchanged++
    }
    $1 == "memory" {
        if ($6 != 1 || $7 != "fragile@24" ||
            $8 != "true" || $9 != "true") exit 2
        unchanged++
    }
    { open += $6; rows++ }
    END {
        if (rows != 3 || open != 27 || home != 1 || unchanged != 2) exit 2
    }
' "$CANDIDATE/natural.tsv"

{
    printf 'metric\ta120_unknown\ta121_role\n'
    printf 'expected_exact_lives\t3/3\t3/3\n'
    printf 'a120_exact_unchanged_lives\t3/3\t2/3\n'
    printf 'open_wonder_turns\t35\t27\n'
    printf 'relational_question_receipts\t3\t0\n'
    printf 'home_questions\tbeneath\ttoy\n'
    printf 'weather_questions\tsmooth\tsmooth\n'
    printf 'memory_questions\tfragile\tfragile\n'
    printf 'result\troles-masquerade-as-things\texact-grammar-refused\n'
} > "$VERDICT"

cat "$VERDICT"
printf 'A.121 lexical-role matrix: %s\n' "$OUT"
