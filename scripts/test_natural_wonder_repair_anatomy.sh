#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-natural-wonder-anatomy-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_NATURAL_PLAN_ONLY=1 \
    "$ROOT/scripts/natural_wonder_repair_anatomy.sh" "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 4 ]
grep -q $'^memory\t401\t' "$TMP/plan/plan.tsv"
grep -q 'don@5,don@12,don@14,belonged@17,belonged@19$' \
    "$TMP/plan/plan.tsv"

cc "$ROOT/scripts/natural_wonder_repair_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/natural-wonder-fixture" -lpthread
"$TMP/natural-wonder-fixture" > "$TMP/anatomy.tsv"
[ "$(wc -l < "$TMP/anatomy.tsv" | tr -d ' ')" -eq 18 ]
grep -q $'^lexical\tcurly-contraction\tnone$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tcurly-function-contraction\tnone$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tknown-curly-possessive\tnone$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tunknown-curly-possessive\tzorble$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tknown-curly-quoted\tnone$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tunknown-curly-quoted\tzorble$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tcurly-contraction-ablation\tdon$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tbeneath\tbeneath$' "$TMP/anatomy.tsv"
grep -q $'^lexical\trainy\trainy$' "$TMP/anatomy.tsv"
grep -q $'^lexical\tbelonged\tbelonged$' "$TMP/anatomy.tsv"
grep -q $'^answer\tanswer-then-followup\tscope=explicit\tgrounded=none\tgrounded_reference=unreferenced$' "$TMP/anatomy.tsv"
grep -q $'^reask\tbeneath-hypothesis-only\t1$' "$TMP/anatomy.tsv"

printf 'natural Wonder repair anatomy contracts: ok\n'
