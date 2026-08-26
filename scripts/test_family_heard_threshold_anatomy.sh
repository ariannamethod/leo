#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-family-heard-threshold-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_FAMILY_HEARD_THRESHOLD_PLAN_ONLY=1 \
    "$ROOT/scripts/family_heard_threshold_matrix.sh" \
    "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^control\t0$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/family_heard_threshold_anatomy.sh" \
    "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 13 ]
[ "$(wc -l < "$TMP/anatomy/interaction.tsv" | tr -d ' ')" -eq 5 ]
[ "$(wc -l < "$TMP/anatomy/corpus.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^natural-onions\tonions\tonion\t2\t2\theard\tonion\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^thin-plural\tzorbles\tzorble\t1\t1\tnone\tnone\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^surface-only\tzorbles\tzorble\t3\t0\tnone\tnone\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^reverse-control\tonion\tonions\t2\t2\tnone\tnone\tnone\tnone$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^1\t0\tonions$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t1\tnone$' "$TMP/anatomy/interaction.tsv"
grep -q $'^startup\t2\t1\t3$' "$TMP/anatomy/corpus.tsv"
grep -q $'^meal-turn-1\t2\t2\t4$' "$TMP/anatomy/corpus.tsv"

[ "$(wc -l < "$ROOT/scripts/family_heard_threshold_expected.tsv" | tr -d ' ')" -eq 7 ]
awk -F '\t' '
    NR == 1 { next }
    NF != 10 { exit 2 }
    $1 == "control" {
        control++
        if ($9 != "true" || $10 != "true") exit 2
    }
    $1 == "candidate" {
        candidate++
        if ($2 == "meal" &&
            ($7 != 23 || $8 != "lentil@2" ||
             $9 != "false" || $10 != "false")) exit 2
        if (($2 == "making" || $2 == "walk") &&
            ($9 != "true" || $10 != "true")) exit 2
    }
    END { if (control != 3 || candidate != 3) exit 2 }
' "$ROOT/scripts/family_heard_threshold_expected.tsv"

printf 'family heard threshold anatomy contracts: ok\n'
