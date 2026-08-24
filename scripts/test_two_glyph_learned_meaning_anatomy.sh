#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-two-glyph-learned-meaning-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_TWO_GLYPH_LEARNED_MEANING_PLAN_ONLY=1 \
    "$ROOT/scripts/two_glyph_learned_meaning_matrix.sh" \
    "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^control\t0$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/two_glyph_learned_meaning_anatomy.sh" \
    "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 37 ]
grep -q $'^control\tnatural-both-expansion\tpending\t.*\tunreferenced\tnone\tnone\tno\tnone\tnone\tflom\t0\tnone\tnone\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tnatural-both-expansion\tpending\t.*\tpaired\tbody\tjoy\tyes\tbody\tjoy\tnone\t1\tbody\tjoy\tbody\tjoy$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\toffered-or\tpending\t.*\tunreferenced\tnone\tnone\tno\tnone\tnone\tflom\t0\tnone\tnone\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\texplicit-and\tpending\t.*\texplicit\tbody\tjoy\tyes\tbody\tjoy\tnone\t1\tbody\tjoy\tbody\tjoy$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tsame-turn-rich-tie\tsame-turn\t.*\tunreferenced\tnone\tnone\tno\tnone\tnone\tnone\t0\tnone\tnone\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tascii-hyphen-both\tpending\t.*\tunreferenced\tnone\tnone\tno\tnone\tnone\tflom\t0\tnone\tnone\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^control\tsingle-food-expansion\tpending\t.*\telliptic\tfood\tnone\tyes\tfood\tnone\tnone\t1\tfood\tnone\tfood\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tsingle-food-expansion\tpending\t.*\telliptic\tfood\tnone\tyes\tfood\tnone\tnone\t1\tfood\tnone\tfood\tnone$' \
    "$TMP/anatomy/anatomy.tsv"

[ "$(wc -l < "$ROOT/scripts/two_glyph_learned_meaning_expected.tsv" | tr -d ' ')" -eq 7 ]
awk -F '\t' '
    NR == 1 { next }
    NF != 10 { exit 2 }
    $1 == "control" {
        control++
        if ($9 != "true" || $10 != "true") exit 2
    }
    $1 == "candidate" {
        candidate++
        if ($2 == "making" &&
            ($7 != 15 || $8 != "sturdier@1,unhurried@11" ||
             $9 != "false" || $10 != "false")) exit 2
        if (($2 == "meal" || $2 == "walk") &&
            ($9 != "true" || $10 != "false")) exit 2
    }
    END { if (control != 3 || candidate != 3) exit 2 }
' "$ROOT/scripts/two_glyph_learned_meaning_expected.tsv"

printf 'two-glyph learned-meaning anatomy contracts: ok\n'
