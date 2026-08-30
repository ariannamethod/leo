#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-two-layer-family-composition-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.133") exit 2; phase++ }
    $1 == "maximum_edges" { if ($2 != 2) exit 2; edges++ }
    $1 == "relation_inventory" { if ($2 != "existing A.120 only") exit 2; inventory++ }
    $1 == "direct_cases" { if ($2 != 12) exit 2; cases++ }
    $1 == "api_turns" { if ($2 != 0) exit 2; api++ }
    END { if (phase != 1 || edges != 1 || inventory != 1 || cases != 1 || api != 1) exit 2 }
' "$ROOT/scripts/two_layer_family_composition_plan.tsv"

LEO_TWO_LAYER_FAMILY_COMPOSITION_PLAN_ONLY=1 \
    "$ROOT/scripts/two_layer_family_composition_matrix.sh" \
    "$TMP/plan" >/dev/null
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 3 ]
grep -q $'^control\t0$' "$TMP/plan/plan.tsv"
grep -q $'^candidate\t1$' "$TMP/plan/plan.tsv"

"$ROOT/scripts/two_layer_family_composition_anatomy.sh" \
    "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/anatomy.tsv" | tr -d ' ')" -eq 13 ]
[ "$(wc -l < "$TMP/anatomy/interaction.tsv" | tr -d ' ')" -eq 5 ]
grep -q $'^natural\tmeaningful\tmeaning\tmean\t1\t1\t7\t0\tnone\tnone\theard\tmean\tnone\tmeaningful$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^thin-chain\tzorbledness\tzorbled\tzorble\t1\t1\t1\t0\tnone\tnone\tnone\tnone\tzorbledness\tzorbledness$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^three-layer\tmeaningfully\tmeaningful\tmeaning\t1\t1\t1\t0\tnone\tnone\tnone\tnone\tmeaningfully\tmeaningfully$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^unrelated\tnewsworthy\tnewsworth\tnews\t1\t1\t7\t0\tnone\tnone\tnone\tnone\tnewsworthy\tnewsworthy$' \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^0\t0\tmeaningful$' "$TMP/anatomy/interaction.tsv"
grep -q $'^0\t1\tnone$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t0\tmeaningful$' "$TMP/anatomy/interaction.tsv"
grep -q $'^1\t1\tnone$' "$TMP/anatomy/interaction.tsv"

awk -F '\t' '
    FNR == NR {
        if (FNR == 1) next
        if (NF != 10 || seen[$1]++) exit 2
        expected[$1] = $9 FS $10
        next
    }
    FNR == 1 { next }
    NF != 14 || !($1 in expected) || ($11 FS $12) != expected[$1] { exit 2 }
    { observed++ }
    END { if (length(expected) != 12 || observed != 12) exit 2 }
' "$ROOT/scripts/two_layer_family_composition_cases.tsv" \
    "$TMP/anatomy/anatomy.tsv"

"$ROOT/scripts/two_layer_family_composition_matrix.sh" \
    "$TMP/matrix" >/dev/null
cmp -s "$ROOT/scripts/two_layer_family_composition_natural.tsv" \
    "$TMP/matrix/natural.tsv"
grep -q $'^control\tmeal\t617\t0\t.*\t12\tlentil@2,meaningful@14\tnone\ttrue\ttrue$' \
    "$TMP/matrix/natural.tsv"
grep -q $'^candidate\tmeal\t617\t1\t.*\t1\tlentil@2\t14,15,16,17\tfalse\tfalse$' \
    "$TMP/matrix/natural.tsv"

printf 'two-layer family composition anatomy contracts: ok\n'
