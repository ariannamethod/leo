#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_RELIABILITY_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_reliability_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 8 || $1 != "cell" || $2 != "group" ||
            $5 != "unspoken_target" || $6 != "spoken_target" ||
            $7 != "unspoken_outcomes" ||
            $8 != "spoken_outcomes")
            exit 1
        next
    }
    {
        if (NF != 8 || cells[$1]++ || groups[$2]++ ||
            $7 != "sustained,sustained,sustained,faded" ||
            $8 != "sustained")
            exit 1
        rows++
    }
    END {
        if (rows != 2 || length(groups) != 2)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite reliability plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite reliability matrix plan: ok\n'
