#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-natural-answer-form-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_NATURAL_ANSWER_FORM_PLAN_ONLY=1 \
    "$ROOT/scripts/natural_answer_form_matrix.sh" "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 5 ]
grep -q $'^control\t0\t0$' "$TMP/plan/plan.tsv"
grep -q $'^expansion-only\t1\t0$' "$TMP/plan/plan.tsv"
grep -q $'^scope-only\t0\t1$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/natural_answer_form_anatomy.sh" "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 14 ]
[ "$(wc -l < "$TMP/anatomy/interaction.tsv" | tr -d ' ')" -eq 5 ]
grep -q $'^offered-em-dash-followup\t.*\tnone\tunreferenced\tfood\telliptic\t1\t0\t0\t0$' "$TMP/anatomy/anatomy.tsv"
grep -q $'^both-em-dash\t.*\tnone\tunreferenced\tnone\tunreferenced\t0\t0\t0\t0$' "$TMP/anatomy/anatomy.tsv"
grep -q $'^negative-em-dash\t.*\tnone\tunreferenced\tnone\telliptic\t0\t1\t0\t0$' "$TMP/anatomy/anatomy.tsv"
grep -q $'^0\t0\t0\tnone\tflom\t1$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t0\t0\tnone\tflom\t1$' "$TMP/anatomy/interaction.tsv"
grep -q $'^0\t1\t0\tnone\tflom\t0$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t1\t1\tfood\tnone\t0$' "$TMP/anatomy/interaction.tsv"

[ "$(wc -l < "$ROOT/scripts/natural_answer_form_expected.tsv" | tr -d ' ')" -eq 13 ]
grep -q $'^candidate\tmeal\t617\t1\t1\t.*\t22\tonions@1,onions@3,guides@5,vegetable@7\tfalse\tfalse$' \
    "$ROOT/scripts/natural_answer_form_expected.tsv"

printf 'natural-answer-form anatomy contracts: ok\n'
