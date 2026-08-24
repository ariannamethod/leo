#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-answer-followup-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_ANSWER_FOLLOWUP_PLAN_ONLY=1 \
    "$ROOT/scripts/answer_followup_anatomy.sh" "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 4 ]
grep -q $'^home\t211\t' "$TMP/plan/plan.tsv"
grep -q $'\t12\ttoy@13$' "$TMP/plan/plan.tsv"

cc "$ROOT/scripts/answer_followup_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/answer-followup-fixture" -lpthread
"$TMP/answer-followup-fixture" > "$TMP/anatomy.tsv"
cmp -s "$ROOT/scripts/answer_followup_cases.tsv" "$TMP/anatomy.tsv"
[ "$(wc -l < "$TMP/anatomy.tsv" | tr -d ' ')" -eq 16 ]
grep -q $'^explicit-followup\t.*\twater\texplicit\t1\t0\t0\tnone\tunreferenced$' "$TMP/anatomy.tsv"
grep -q $'^anaphoric-followup\t.*\twater\tanaphoric\t1\t0\t0\tnone\tunreferenced$' "$TMP/anatomy.tsv"
grep -q $'^tail-evidence-isolated\t.*\tanimal\texplicit\t0\t0\t1\tnone\tunreferenced$' "$TMP/anatomy.tsv"
grep -q $'^sensory-anaphora\t.*\tnone\tunreferenced\t0\t0\t0\tnone\tunreferenced$' "$TMP/anatomy.tsv"
grep -q $'^negative-followup\t.*\tnone\texplicit\t0\t1\t0\tnone\tunreferenced$' "$TMP/anatomy.tsv"

printf 'answer-followup anatomy contracts: ok\n'
