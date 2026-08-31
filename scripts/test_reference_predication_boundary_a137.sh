#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-reference-predication-a137-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.137") exit 2; phase++ }
    $1 == "api_turns" { if ($2 != 0) exit 2; api++ }
    $1 == "state_format_change" { if ($2 != "forbidden") exit 2; state++ }
    $1 == "control" { if ($2 !~ /^named ablation/) exit 2; control++ }
    END { if (phase != 1 || api != 1 || state != 1 || control != 1) exit 2 }
' "$ROOT/scripts/reference_predication_boundary_a137_plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "case" || $10 != "control_alternate") exit 2
        next
    }
    NF != 10 || seen[$1]++ ||
        ($6 != "explicit" && $6 != "anaphoric" && $6 != "elliptic") { exit 2 }
    { rows++ }
    $1 ~ /^(he-after|she-after|child-after|co-present-child)$/ &&
        $4 == "none" && $9 != "none" { refused++ }
    $1 == "natural-negative-correction" && $8 == 1 { natural_negative++ }
    $1 == "paired-definition" && $4 == "water" && $5 == "animal" { pair++ }
    END {
        if (rows != 15 || refused != 4 ||
            natural_negative != 1 || pair != 1) exit 2
    }
' "$ROOT/scripts/reference_predication_boundary_a137_cases.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 11 || $1 != "phase" || $11 != "school_questions") exit 2
        next
    }
    NF != 11 || $1 != "A.137" ||
        $3 !~ /^[0-9a-f]{64}$/ || $4 !~ /^[0-9a-f]{64}$/ ||
        $5 !~ /^[0-9a-f]{64}$/ || $6 !~ /^[0-9a-f]{64}$/ ||
        $7 != 5 || $8 != 26 || $9 != 22 || $10 != 12 ||
        $11 != "lentil@2,difficult@15,difficult@25" { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$ROOT/scripts/reference_predication_boundary_a137_frozen.tsv"

"$ROOT/scripts/reference_predication_boundary_a137_anatomy.sh" \
    "$TMP/anatomy" > "$TMP/anatomy.out"
grep -q $'^false_lessons_refused\t4$' "$TMP/anatomy.out"
grep -q $'^positive_answer_forms_preserved\t7$' "$TMP/anatomy.out"
grep -q $'^negative_forms_preserved\t2$' "$TMP/anatomy.out"
grep -q $'^historical_a136_control_exact\ttrue$' "$TMP/anatomy.out"
grep -q $'^reply_exact_through_turn\t26$' "$TMP/anatomy.out"
cmp -s "$ROOT/scripts/reference_predication_boundary_a137_expected.tsv" \
    "$TMP/anatomy/direct.tsv"
cmp -s "$ROOT/scripts/reference_predication_boundary_a137_natural.tsv" \
    "$TMP/anatomy/natural.tsv"

printf 'reference-predication boundary A.137 contracts: ok\n'
