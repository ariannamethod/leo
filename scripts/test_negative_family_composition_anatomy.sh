#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-negative-family-composition-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_NEGATIVE_FAMILY_COMPOSITION_PLAN_ONLY=1 \
    "$ROOT/scripts/negative_family_composition_matrix.sh" \
    "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^control\t0$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/negative_family_composition_anatomy.sh" \
    "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 13 ]
[ "$(wc -l < "$TMP/anatomy/interaction.tsv" | tr -d ' ')" -eq 5 ]
grep -q $'^natural\tunhurried\theard\thurry\tnone\tunhurried$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^learned-root\tunzorbled\tmeaning\tzorble\tnone\tunzorbled$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^unknown-root\tunflimmed\tnone\tnone\tunflimmed\tunflimmed$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^indivisible\tunique\tnone\tnone\tunique\tunique$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^0\t1\tnone$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t0\tunhurried$' "$TMP/anatomy/interaction.tsv"

[ "$(wc -l < "$ROOT/scripts/negative_family_composition_expected.tsv" | tr -d ' ')" -eq 7 ]
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
            ($7 != 10 || $8 != "sturdier@1,prefer@16" ||
             $9 != "false" || $10 != "false")) exit 2
        if (($2 == "meal" || $2 == "walk") &&
            ($9 != "true" || $10 != "true")) exit 2
    }
    END { if (control != 3 || candidate != 3) exit 2 }
' "$ROOT/scripts/negative_family_composition_expected.tsv"

printf 'negative family composition anatomy contracts: ok\n'
