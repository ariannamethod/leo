#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-lexical-role-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_LEXICAL_ROLE_PLAN_ONLY=1 \
    "$ROOT/scripts/lexical_role_anatomy.sh" "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 4 ]
grep -q $'^home\t211\t' "$TMP/plan/plan.tsv"
grep -q $'\t20\tbeneath@5,beneath@11,beneath@18\t' "$TMP/plan/plan.tsv"
grep -q $'\t12\ttoy@13$' "$TMP/plan/plan.tsv"

cc "$ROOT/scripts/lexical_role_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/lexical-role-fixture" -lpthread
"$TMP/lexical-role-fixture" > "$TMP/anatomy.tsv"
[ "$(wc -l < "$TMP/anatomy.tsv" | tr -d ' ')" -eq 38 ]
grep -q $'^relation\tbeneath\trelation\tunder\tnone\tbeneath$' "$TMP/anatomy.tsv"
grep -q $'^relation\tnearby\trelation\tby\tnone\tnearby$' "$TMP/anatomy.tsv"
grep -q $'^polarity\tnor\tpolarity\tnot\tnone\tnor$' "$TMP/anatomy.tsv"
grep -q $'^polarity\twithout\tpolarity\tnot\tnone\twithout$' "$TMP/anatomy.tsv"
grep -q $'^discourse\thowever\tdiscourse\tbut\tnone\thowever$' "$TMP/anatomy.tsv"
grep -q $'^historical-operator\tlike\tnone\tnone\tnone\tnone$' "$TMP/anatomy.tsv"
grep -q $'^exact-control\tbeneathness\tnone\tnone\tbeneathness\tbeneathness$' "$TMP/anatomy.tsv"
grep -q $'^exact-control\tsurround\tnone\tnone\tsurround\tsurround$' "$TMP/anatomy.tsv"
grep -q $'^question-control\ttoy\tnone\tnone\ttoy\ttoy$' "$TMP/anatomy.tsv"
grep -q $'^question-control\tsmooth\tnone\tnone\tsmooth\tsmooth$' "$TMP/anatomy.tsv"
grep -q $'^question-control\tfragile\tnone\tnone\tfragile\tfragile$' "$TMP/anatomy.tsv"
grep -q $'^meaning-control\tnothing\tnone\tnone\tnone\tnone$' "$TMP/anatomy.tsv"

printf 'lexical-role anatomy contracts: ok\n'
