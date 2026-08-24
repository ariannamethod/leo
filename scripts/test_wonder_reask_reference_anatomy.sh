#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-wonder-reask-reference-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_WONDER_REASK_REFERENCE_PLAN_ONLY=1 \
    "$ROOT/scripts/wonder_reask_reference_anatomy.sh" "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 4 ]
grep -q $'^weather\t307\t' "$TMP/plan/plan.tsv"
grep -q $'\t14\tsmooth@11$' "$TMP/plan/plan.tsv"

cc "$ROOT/scripts/wonder_reask_reference_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/wonder-reask-reference-fixture" -lpthread
"$TMP/wonder-reask-reference-fixture" > "$TMP/anatomy.tsv"
cmp -s "$ROOT/scripts/wonder_reask_reference_cases.tsv" "$TMP/anatomy.tsv"
[ "$(wc -l < "$TMP/anatomy.tsv" | tr -d ' ')" -eq 14 ]
grep -q $'^exact-statement\t.*\t1\t1\t1\t1$' "$TMP/anatomy.tsv"
grep -q $'^anaphoric-inverted\t.*\t1\t1\t1\t1$' "$TMP/anatomy.tsv"
grep -q $'^plain-hypothesis\t.*\t0\t0\t1\t1$' "$TMP/anatomy.tsv"
grep -q $'^prior-clause-only\t.*\t0\t0\t1\t1$' "$TMP/anatomy.tsv"
grep -q $'^unrelated\t.*\t0\t0\t0\t0$' "$TMP/anatomy.tsv"

printf 'wonder-reask-reference anatomy contracts: ok\n'
