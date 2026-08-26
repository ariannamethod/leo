#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-presence-surface-boundary-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_PRESENCE_SURFACE_BOUNDARY_PLAN_ONLY=1 \
    "$ROOT/scripts/presence_surface_boundary_matrix.sh" \
    "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^control\t0$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/presence_surface_boundary_anatomy.sh" \
    "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 11 ]
[ "$(wc -l < "$TMP/anatomy/interaction.tsv" | tr -d ' ')" -eq 5 ]
grep -q $'^exact-case\train\tRAIN\.\t1\t1$' "$TMP/anatomy/anatomy.tsv"
grep -q $'^infix-training\train\tTraining takes time\.\t0\t1$' "$TMP/anatomy/anatomy.tsv"
grep -q $'^compound-raincoat\train\tHis raincoat is warm\.\t0\t1$' "$TMP/anatomy/anatomy.tsv"
grep -q $'^possessive-rains\train\tRain'"'"'s sound remains\.\t0\t1$' "$TMP/anatomy/anatomy.tsv"
grep -q $'^0\t1\t0\t0$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t0\t1\t0$' "$TMP/anatomy/interaction.tsv"

[ "$(wc -l < "$ROOT/scripts/presence_surface_boundary_expected.tsv" | tr -d ' ')" -eq 7 ]
awk -F '\t' '
    NR == 1 { next }
    NF != 10 || $9 != "true" || $10 != "true" { exit 2 }
    $1 == "control" { control++ }
    $1 == "candidate" { candidate++ }
    END { if (control != 3 || candidate != 3) exit 2 }
' "$ROOT/scripts/presence_surface_boundary_expected.tsv"

printf 'presence surface boundary anatomy contracts: ok\n'
