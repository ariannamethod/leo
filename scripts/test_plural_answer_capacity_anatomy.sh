#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-plural-answer-capacity-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_PLURAL_ANSWER_CAPACITY_PLAN_ONLY=1 \
    "$ROOT/scripts/plural_answer_capacity_matrix.sh" "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^control\t0$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/plural_answer_capacity_anatomy.sh" "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 31 ]
grep -q $'^control\tpending\texplicit-tie-body-first\t.*\texplicit\tbody\t1\t2\t1\t1\t0\t0$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tpending\texplicit-tie-body-first\t.*\texplicit\tnone\t1\t2\t1\t1\t0\t0$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^control\tsame-turn\tdefinition-rich-tie\t.*\tdefinition\twater\t1\t3\t0\t0\t0\t0$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tsame-turn\tdefinition-rich-tie\t.*\tdefinition\tnone\t1\t3\t0\t0\t0\t0$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tpending\texplicit-unique-dominant\t.*\texplicit\tbody\t2\t1\t2\t1\t0\t0$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^candidate\tpending\tnatural-both-expansion\t.*\tunreferenced\tnone\t0\t0\t0\t0\t0\t0$' \
    "$TMP/anatomy/anatomy.tsv"

[ "$(wc -l < "$ROOT/scripts/plural_answer_capacity_expected.tsv" | tr -d ' ')" -eq 7 ]
awk -F '\t' '
    NR == 1 { next }
    NF != 10 || $9 != "true" || $10 != "true" { exit 2 }
    { rows++ }
    END { if (rows != 6) exit 2 }
' "$ROOT/scripts/plural_answer_capacity_expected.tsv"

printf 'plural-answer-capacity anatomy contracts: ok\n'
