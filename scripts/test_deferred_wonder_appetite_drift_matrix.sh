#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_DRIFT_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_drift_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 8 || $1 != "cell" || $2 != "group" ||
            $6 != "early_outcomes" || $7 != "recent_outcomes" ||
            $8 != "expected_drift")
            exit 1
        next
    }
    {
        if (NF != 8 || cells[$1]++ || groups[$2]++)
            exit 1
        if ($2 == "old" &&
            ($6 != "faded,faded,faded,faded" ||
             $7 != "sustained,sustained,sustained,sustained" ||
             $8 != "rising"))
            exit 1
        if ($2 == "new" &&
            ($6 != "sustained,sustained,sustained,sustained" ||
             $7 != "faded,faded,faded,faded" ||
             $8 != "falling"))
            exit 1
        rows++
    }
    END {
        if (rows != 2 || length(groups) != 2)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite drift plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite drift matrix plan: ok\n'
