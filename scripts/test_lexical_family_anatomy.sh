#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-lexical-family-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_LEXICAL_PLAN_ONLY=1 \
    "$ROOT/scripts/lexical_family_anatomy.sh" "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 4 ]
grep -q $'^weather\t307\t' "$TMP/plan/plan.tsv"
grep -q $'\t20\trainy@5,rainy@7,rainy@24\t' "$TMP/plan/plan.tsv"
grep -q $'\t1\tfragile@24$' "$TMP/plan/plan.tsv"

cc "$ROOT/scripts/lexical_family_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/lexical-family-fixture" -lpthread
"$TMP/lexical-family-fixture" > "$TMP/anatomy.tsv"
[ "$(wc -l < "$TMP/anatomy.tsv" | tr -d ' ')" -eq 26 ]
grep -q $'^suffix\trainy\tmeaning\train\tnone\trainy$' "$TMP/anatomy.tsv"
grep -q $'^suffix\tbelonged\theard\tbelong\tnone\tbelonged$' "$TMP/anatomy.tsv"
grep -q $'^compound\toutdoors\tcompound\toutdoor\tnone\toutdoors$' "$TMP/anatomy.tsv"
grep -q $'^orthography\tneighbor\theard\tneighbour\tnone\tneighbor$' "$TMP/anatomy.tsv"
grep -q $'^irregular\tloss\tmeaning\tlost\tnone\tloss$' "$TMP/anatomy.tsv"
grep -q $'^irregular\tbring\theard\tbrought\tnone\tbring$' "$TMP/anatomy.tsv"
grep -q $'^whole-word-control\tnews\tnone\tnone\tnews\tnews$' "$TMP/anatomy.tsv"
grep -q $'^substring-control\tlover\tmeaning\tlove\tnone\tlover$' "$TMP/anatomy.tsv"
grep -q $'^substring-control\tmoth\tnone\tnone\tmoth\tmoth$' "$TMP/anatomy.tsv"
grep -q $'^substring-control\tthing\tnone\tnone\tthing\tthing$' "$TMP/anatomy.tsv"
grep -q $'^grammar-compound-control\twithout\tnone\tnone\twithout\twithout$' "$TMP/anatomy.tsv"
grep -q $'^unwitnessed-root-control\tsmooth\tnone\tnone\tsmooth\tsmooth$' "$TMP/anatomy.tsv"
grep -q $'^unlearned-root-control\tzorbled\tnone\tnone\tzorbled\tzorbled$' "$TMP/anatomy.tsv"
grep -q $'^learned-root\tzorbled\tmeaning\tzorble\tnone\tzorbled$' "$TMP/anatomy.tsv"

printf 'lexical-family anatomy contracts: ok\n'
