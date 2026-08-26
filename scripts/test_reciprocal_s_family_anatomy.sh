#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-reciprocal-s-family-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_RECIPROCAL_S_FAMILY_PLAN_ONLY=1 \
    "$ROOT/scripts/reciprocal_s_family_matrix.sh" \
    "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^control\t0$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/reciprocal_s_family_anatomy.sh" \
    "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 11 ]
[ "$(wc -l < "$TMP/anatomy/interaction.tsv" | tr -d ' ')" -eq 5 ]
grep -q $'^natural\tprefer\theard\tprefers\tnone\tprefer$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^learned\tprefer\tmeaning\tprefers\tnone\tprefer$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^unlisted\tzorble\tnone\tnone\tzorble\tzorble$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^threshold\tprefer\tnone\tnone\tprefer\tprefer$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^grammar\talway\tnone\tnone\talway\talway$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^0\t1\tnone$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t0\tprefer$' "$TMP/anatomy/interaction.tsv"

[ "$(wc -l < "$ROOT/scripts/reciprocal_s_family_expected.tsv" | tr -d ' ')" -eq 7 ]
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
            ($7 != 8 || $8 != "sturdier@1,courage@18" ||
             $9 != "false" || $10 != "false")) exit 2
        if (($2 == "meal" || $2 == "walk") &&
            ($9 != "true" || $10 != "true")) exit 2
    }
    END { if (control != 3 || candidate != 3) exit 2 }
' "$ROOT/scripts/reciprocal_s_family_expected.tsv"

printf 'reciprocal final-s family anatomy contracts: ok\n'
